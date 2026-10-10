/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <assert.h>
#include <musa.h>
#include <musa_runtime.h>
#include <unistd.h>
#include "utils.h"
#include "ibgda_device.cuh"
#include <sys/time.h>
#include <vector>

#define MAX_BUFFER_SIZE 1024 * 1024 * 1024
#define THREADS_PER_WARP 32

using namespace deep_ep;


__global__ void latency_block(uint8_t *input, uint8_t *buffer, int *topk_idx, int *atomic_counter_per_expert, int* flag, volatile unsigned int *counter_d, 
    int rank, int num_ranks, int num_topk, int num_experts, int num_tokens, int num_bytes_per_msg, bool waitmode) { 
    const auto sm_id = static_cast<int>(blockIdx.x);
    const auto thread_id = static_cast<int>(threadIdx.x);
    const auto warp_id = thread_id / THREADS_PER_WARP;
    const auto lane_id = thread_id % THREADS_PER_WARP;
    const auto num_sms = static_cast<int>(gridDim.x);
    const auto num_warps = static_cast<int>(blockDim.x) / THREADS_PER_WARP;
    const auto num_local_experts = num_experts / num_ranks;

    for (int token_idx = sm_id; token_idx < num_tokens; token_idx += num_sms) {
      auto dst_expert_idx = warp_id < num_topk ? __ldg(topk_idx + token_idx * num_topk + warp_id) : -1;
      if (dst_expert_idx >= 0) {
        int slot_idx = lane_id == 0 ? atomicAdd(atomic_counter_per_expert + dst_expert_idx, 1) : 0;
        slot_idx = __shfl_sync(0xffffffff, slot_idx, 0);
        const auto dst_rank = dst_expert_idx / num_local_experts;
        const auto dst_expert_local_idx = dst_expert_idx % num_local_experts;
        const auto src_ptr = reinterpret_cast<uint64_t>(input + token_idx * num_bytes_per_msg);
        const auto dst_ptr = reinterpret_cast<uint64_t>(buffer +
                              dst_expert_local_idx * num_ranks * num_tokens * num_bytes_per_msg +
                              rank * num_tokens * num_bytes_per_msg +
                              slot_idx * num_bytes_per_msg);
        if(dst_rank != rank) {
          nvshmemi_ibgda_put_nbi_warp(dst_ptr, src_ptr, num_bytes_per_msg, dst_rank, dst_expert_local_idx, lane_id, slot_idx);
          if (waitmode) nvshmemi_ibgda_quiet(dst_rank, dst_expert_local_idx);
        }
      }
        // do something here
        // __nanosleep(500);
    }
    __syncthreads();
}

int main(int argc, char *argv[]) {
    int mype, npes;
    int skip = 20;
    const int num_topk = 8;
    int num_experts = 288;
    int num_tokens = 128;
    int sms = 48;
    int psize = 7408;
    bool waitmode = false;
    bool block_only = false;
    bool address_scatter = false;
    int loop = 1;
    bool printk = false;
    int num_device_sms = 1;
    int num_warp_groups = 1;
    int num_warps_per_group = 1;

    void **h_tables;
    uint64_t *h_size_arr;
    double *h_lat;
    uint8_t *input_d = NULL;
    uint8_t *buffer_d = NULL;
    int * atomic_counter_per_expert_d = NULL;
    int *flag = NULL;
    int *topk_idx_d = NULL;
    unsigned int *counter_d = NULL;
    float milliseconds;
    musaEvent_t start, stop;

    init_wrapper(&argc, &argv);
    while (1) {
        int c;
        c = getopt(argc, argv, "s:q:l:t:e:whp");

        if (c == -1) break;

        switch (c) {
        case 's':
            psize = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "packet size is %d \n", psize);
            break;
        case 'p':
            printk = true;
            break;
        case 'q':
            sms = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "qp sms is %d \n", sms);
            break;
        case 'l':
            loop = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "loop is %d \n", loop);
            break;
        case 't':
            num_tokens = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "num_tokens is %d \n", num_tokens);
            break;
        case 'e':
            num_experts = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "num_experts is %d \n", num_experts);
            break;
        case 'w':
            waitmode = true;
            if (mype == 0) fprintf(stderr, "wait mode on\n");
            break;
        default:
        case 'h':
            printf("-q num_sms -s msg_bytes -l iterations -t tokenNumber -e expertNumber -w(wait for quiet) \n");
            exit(0);
        }
    } 

    musaEventCreate(&start);
    musaEventCreate(&stop);
    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();

    if (npes != num_topk) {
        fprintf(stderr, "This test requires exactly %d processes \n", num_topk);
        exit(1);
    }

    input_d = (uint8_t *)nvshmem_align(128, num_tokens * psize);
    buffer_d  = (uint8_t *)nvshmem_align(128, num_experts * num_tokens * psize);

    // generate topk_idx, banlanced
    MUSA_CHECK(musaMalloc((void **)&topk_idx_d, sizeof(int) * num_tokens * num_topk));
    std::vector<int> topk_idx_h(num_tokens * num_topk);
    auto experts_per_rank = num_experts / npes;
    for(int i = 0; i < num_tokens; i++) {
      auto offset = i % experts_per_rank;
      for(int j = 0; j < num_topk; j++) {
        topk_idx_h[i * num_topk + j] = offset + experts_per_rank * j;
      }
    }

    // 添加打印topk_idx_h数组的代码
    if (printk && mype == 0) {
        printf("Printing topk_idx_h array:\n");
        for (int i = 0; i < 128; i++) {
            for (int j = 0; j < 8; j++) {
                int index = i * 8 + j;
                if (index < num_tokens * num_topk) {
                    printf("%d ", topk_idx_h[index]);
                }
            }
            printf("\n");
        }
    }

    MUSA_CHECK(musaMemcpy(topk_idx_d, topk_idx_h.data(), sizeof(int) * num_tokens * num_topk, musaMemcpyHostToDevice));
    flag = (int *)nvshmem_malloc(sizeof(int));
    MUSA_CHECK(musaMemset(flag, 0, sizeof(int)));
    MUSA_CHECK(musaMalloc((void **)&atomic_counter_per_expert_d, sizeof(int) * num_experts));
    MUSA_CHECK(musaMemset(atomic_counter_per_expert_d, 0, sizeof(int) * num_experts));
    MUSA_CHECK(musaMalloc((void **)&counter_d, sizeof(unsigned int) * 1024));
    MUSA_CHECK(musaMemset(counter_d, 0, sizeof(unsigned int) * 1024));
    MUSA_CHECK(musaDeviceSynchronize());

    alloc_tables(&h_tables, 2, 1);
    h_size_arr = (uint64_t *)h_tables[0];
    h_lat = (double *)h_tables[1];
    nvshmem_barrier_all();
    MUSA_CHECK(musaDeviceSynchronize());
    nvshmem_quiet();

    // 对称分配一块内存来存放所有 PE 的 lat
    double *all_lat = (double *)nvshmem_malloc(npes * sizeof(double));
    double *all_lat_h = (double *)malloc(npes * sizeof(double));

    for (int j = 0; j < loop; j++)
    {
        musaMemset(counter_d, 0, sizeof(unsigned int) * 1024);
        musaMemset(atomic_counter_per_expert_d, 0, sizeof(int) * num_experts);

        latency_block<<<1, THREADS_PER_WARP * num_topk>>>(input_d, buffer_d, topk_idx_d, atomic_counter_per_expert_d, 
          flag, counter_d, mype, npes, num_topk, num_experts, num_tokens, psize, waitmode);

        musaMemset(counter_d, 0, sizeof(unsigned int) * 1024);
        musaMemset(atomic_counter_per_expert_d, 0, sizeof(int) * num_experts);
        musaDeviceSynchronize();

        musaEventRecord(start);
        latency_block<<<sms, THREADS_PER_WARP * num_topk>>>(input_d, buffer_d, topk_idx_d, atomic_counter_per_expert_d,
          flag, counter_d, mype, npes, num_topk, num_experts, num_tokens, psize, waitmode);
        musaEventRecord(stop);

        MUSA_CHECK(musaGetLastError());
        MUSA_CHECK(musaEventSynchronize(stop));

        nvshmem_quiet();
        
        /* give latency in us */
        musaEventElapsedTime(&milliseconds, start, stop);
        h_lat[0] = (milliseconds * 1000);

        nvshmem_barrier_all();
        nvshmem_double_p(&all_lat[mype], h_lat[0], 0);  // 把lat放到PE0的lat_all[mype]中
        nvshmem_barrier_all();

        MUSA_CHECK(musaMemcpy(all_lat_h, all_lat, npes * sizeof(double), musaMemcpyDeviceToHost));
        MUSA_CHECK(musaDeviceSynchronize());

        if (mype == 0) {
            for(int k = 0; k < npes; k++)
            {
                if (waitmode)
                {
                    double bw = (double)psize * num_tokens * num_topk / all_lat_h[k] / 1000.0;
                    printf("[PE%d]deepep igbda size %d send wait latency: %fus (%fus) bw %f GB/s\n", k, psize , milliseconds * 1000, all_lat_h[k], bw);
                }else {
                    printf("[PE%d]deepep igbda size %d send latency: %fus\n",k ,psize , all_lat_h[k]);
                }
            }
        }
    }

    if(all_lat) nvshmem_free(all_lat);
    if (input_d) nvshmem_free(input_d);
    if (buffer_d) nvshmem_free(buffer_d);
    if (flag) nvshmem_free(flag);
    musaFree(counter_d);
    free_tables(h_tables, 2);

    finalize_wrapper();

    return 0;
}
