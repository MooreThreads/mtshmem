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

#define MAX_BUFFER_SIZE 1024 * 1024 * 1024
#define MAX_MSG_SIZE 16 * 1024 * 1024
#define MIN_MSG_SIZE 4 * 1024
#define THREADS_PER_WARP 32
#define THREADS_PER_BLOCK 1024

using namespace deep_ep;

__global__ void latency_warp(int *data_d, int* flag, int len, int pe, int iter) { 
    int i, tid, peer, lane_id;
    uint64_t data_ptr = reinterpret_cast<uint64_t>(data_d);

    peer = !pe;
    tid = threadIdx.x;
    
    lane_id = tid % 32;

    for (i = 0; i < iter; i++) {
        nvshmemi_ibgda_put_nbi_warp(data_ptr, data_ptr, len, peer, 0, lane_id, 0);
                                                                            
        __syncthreads();                                                  
        if (!tid) nvshmemi_ibgda_quiet(peer, 0);
        __syncthreads();
    }
    // nvshmemi_ibgda_amo_nonfetch_add(flag, 1, peer, 0);
}

__global__ void latency_block(int *data_d, int* flag, volatile unsigned int *counter_d, int len, int pe, int iter, bool waitmode, bool address_scatter) { 
    int i = 0;
    int tid, peer, lane_id;
    uint64_t data_ptr = reinterpret_cast<uint64_t>(data_d);
    int npes = nvshmem_n_pes();
    int n_warps_per_sm = npes;

    tid = threadIdx.x;
    
    lane_id = tid % 32;
    int sm_id = blockIdx.x;
    int num_sms = gridDim.x;
    int counter = 0;

    int split_size = len / num_sms;
    const auto warp_id = tid / THREADS_PER_WARP;
    peer = -1;
    if ((warp_id != pe) && (warp_id < n_warps_per_sm))
    {
        peer = warp_id;
        for (i = 0; i < iter; i++) {
            // len = 8K ->7408Bytes
            // different sm handle different data
            if (address_scatter) {
                nvshmemi_ibgda_put_nbi_warp<false>(
                    data_ptr + sm_id * split_size, data_ptr, split_size, peer, sm_id, lane_id, i);
            } else {
                nvshmemi_ibgda_put_nbi_warp<false>(
                    data_ptr, data_ptr, split_size, peer, sm_id, lane_id, i);
            }

            // do something here
            // __nanosleep(500);
        }
    }
    __syncthreads();
    if ((lane_id == 0) && (peer >= 0)) nvshmemi_ibgda_amo_nonfetch_add(flag + sm_id * n_warps_per_sm + warp_id, 1, peer, sm_id);
    if (waitmode && (lane_id == 0) && (peer >= 0)) nvshmemi_ibgda_quiet(peer, sm_id);

    // Wait all blocks sync here
    // if (waitmode && (0 == tid)) {
    //     // __musa_fence_rel();
    //     // __threadfence_system();
    //     // counter = atomicInc((unsigned int *)counter_d, UINT_MAX);
    //     counter = atomicAdd((unsigned int *)counter_d, 1);
    //     // printf("counter: %d, block: %d\n", counter, blockIdx.x);
    //     if (counter == (num_sms - 1)) {
    //         nvshmem_quiet();
    //         *(counter_d + 1) += 1;
    //     }
    //     __musa_fence_rel();
    //     while (*(counter_d + 1) != 1);
    // }
    __syncthreads();
    // nvshmemi_ibgda_amo_nonfetch_add(flag, 1, peer, 0);
}

int main(int argc, char *argv[]) {
    int mype, npes, size;
    int iter = 600;
    int skip = 20;
    int sms = 1;
    int psize = 7408;
    bool waitmode = false;
    bool block_only = false;
    bool address_scatter = false;
    int loop = 1;
    int enable_pes = 1;
    int array_size, i;
    int max_msg_size = MAX_MSG_SIZE;
    int min_msg_size = MIN_MSG_SIZE;

    int *data_d = NULL;
    int *flag = NULL;
    unsigned int *counter_d = NULL;
    void **h_tables;
    uint64_t *h_size_arr;
    double *h_lat;

    float milliseconds;
    musaEvent_t start, stop;

    // init
    init_wrapper(&argc, &argv);
    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();
    enable_pes = npes;
    // 对称分配一块内存来存放所有 PE 的 lat
    double *all_lat = (double *)nvshmem_malloc(npes * sizeof(double));
    double *all_lat_h = (double *)malloc(npes * sizeof(double));

    while (1) {
        int c;
        c = getopt(argc, argv, "s:q:l:i:e:wbhx");

        if (c == -1) break;

        switch (c) {
        case 's':
            psize = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "packet size is %d \n", psize);
            break;
        case 'q':
            sms = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "qp sms is %d \n", sms);
            break;
        case 'i':
            iter = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "iter is %d \n", iter);
            break;
        case 'l':
            loop = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "loop is %d \n", loop);
            break;
        case 'b':
            block_only = true;
            if (mype == 0) fprintf(stderr, "block test only\n");
            break;
        case 'w':
            waitmode = true;
            if (mype == 0) fprintf(stderr, "wait mode on\n");
            break;
        case 'x':
            address_scatter = true;
            if (mype == 0) fprintf(stderr, "address scatter on\n");
            break;
        case 'e':
            enable_pes = strtol(optarg, NULL, 0);
            if (mype == 0) fprintf(stderr, "enable_pes is %d \n", enable_pes);
            break;
        default:
        case 'h':
            printf("-q num_sms -s msg_bytes -l iterations -w(wait for quiet) -b(block test only)\n");
            goto finalize;
        }
    } 

    musaEventCreate(&start);
    musaEventCreate(&stop);

    if (npes < 2) {
        fprintf(stderr, "This test requires at least two processes \n");
        goto finalize;
    }

    data_d = (int *)nvshmem_malloc(MAX_BUFFER_SIZE);
    flag = (int *)nvshmem_malloc(sizeof(int) * npes * sms);
    MUSA_CHECK(musaMemset(data_d, 0, MAX_BUFFER_SIZE));
    MUSA_CHECK(musaMemset(flag, 0, sizeof(int) * npes * sms));
    MUSA_CHECK(musaMalloc((void **)&counter_d, sizeof(unsigned int) * 1024));
    MUSA_CHECK(musaMemset(counter_d, 0, sizeof(unsigned int) * 1024));
    MUSA_CHECK(musaDeviceSynchronize());

    array_size = floor(std::log2((float)max_msg_size)) + 1;
    alloc_tables(&h_tables, 2, array_size);
    h_size_arr = (uint64_t *)h_tables[0];
    h_lat = (double *)h_tables[1];

    nvshmem_barrier_all();
    MUSA_CHECK(musaDeviceSynchronize());
    nvshmem_quiet();

    // one SM with one warp 
    if (!block_only) {
        i = 0;
        for (size = min_msg_size; size <= max_msg_size; size *= 2) {
            if (mype < enable_pes) {
                int nelems;
                h_size_arr[i] = size;

                latency_warp<<<1, THREADS_PER_WARP>>>(data_d, flag, size, mype, skip);
                musaEventRecord(start);
                latency_warp<<<1, THREADS_PER_WARP>>>(data_d, flag, size, mype, iter);
                musaEventRecord(stop);

                MUSA_CHECK(musaGetLastError());
                MUSA_CHECK(musaEventSynchronize(stop));

                /* give latency in us */
                musaEventElapsedTime(&milliseconds, start, stop);
                h_lat[i] = (milliseconds * 1000) / iter;
                i++;
            }
            nvshmem_barrier_all();
        }
        if (mype == 0) {
            print_table_v1("deepep_put_latency", "warp(1QP)", "size (Bytes)", "latency", "us", '-',
                        h_size_arr, h_lat, i);
        }
    }
    nvshmem_quiet();
    if (mype == 0) printf("deepep_put_latency multi SM with one warp using multi QPs\n");

    // multi SM using multi QPs
    for (int j = 0; j < loop; j++)
    {  
        i = 0;
        size = psize;
        float host_lat;
        if (mype < enable_pes) {
            int nelems;
            h_size_arr[i] = size;

            // 模拟多个SM，每个SM传size大小的数据，因此总数据量为size * sms
            latency_block<<<1, THREADS_PER_WARP * npes>>>(data_d, flag, counter_d, size * sms, mype, skip, waitmode, address_scatter);
            musaMemset(counter_d, 0, sizeof(unsigned int) * 1024);
            musaDeviceSynchronize();
            musaEventRecord(start);
            // 模拟多个SM，每个SM传size大小的数据，因此总数据量为size * sms
            latency_block<<<sms, THREADS_PER_WARP * npes>>>(data_d, flag, counter_d, size * sms, mype, iter, waitmode, address_scatter);
            musaEventRecord(stop);

            MUSA_CHECK(musaGetLastError());
            MUSA_CHECK(musaEventSynchronize(stop));
            nvshmem_quiet();
            
            /* give latency in us */
            musaEventElapsedTime(&milliseconds, start, stop);
            h_lat[i] = (milliseconds * 1000) / iter;
            i++;
        }
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
                    double bw = (double)size * (npes -1) * sms / all_lat_h[k] / 1000.0;
                    printf("[PE%d]deepep igbda size %d send wait latency: %fus (%fus) bw %f GB/s\n", k, psize , milliseconds * 1000, all_lat_h[k], bw);
                }else {
                    printf("[PE%d]deepep igbda size %d send latency: %fus\n",k ,psize , all_lat_h[k]);
                }
            }
            printf("=============LOOP %d END================\n", j);
        }
    }

finalize:

    if (all_lat) nvshmem_free(all_lat);
    if (data_d) nvshmem_free(data_d);
    if (flag) nvshmem_free(flag);
    free_tables(h_tables, 2);

    finalize_wrapper();

    return 0;
}
