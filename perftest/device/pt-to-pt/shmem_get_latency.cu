/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#define CUMODULE_NAME "shmem_get_latency.cubin"

#include <stdio.h>
#include <assert.h>
#include <musa.h>
#include <musa_runtime.h>
#include <unistd.h>
#include "utils.h"

#define THREADS_PER_WARP 32

#if defined __cplusplus || defined NVSHMEM_HOSTLIB_ONLY
extern "C" {
#endif

__global__ void latency_kern(int *data_d, int len, int pe, int iter) {
    int i, peer;

    peer = !pe;

    for (i = 0; i < iter; i++) {
        nvshmem_int_get_nbi(data_d, data_d, len, peer);
        nvshmem_quiet();
    }
}

#define LATENCY_THREADGROUP(group)                                                 \
    __global__ void latency_kern_##group(int *data_d, int len, int pe, int iter) { \
        int i, tid, peer;                                                          \
                                                                                   \
        peer = !pe;                                                                \
        tid = threadIdx.x;                                                         \
                                                                                   \
        for (i = 0; i < iter; i++) {                                               \
            nvshmemx_int_get_nbi_##group(data_d, data_d, len, peer);               \
                                                                                   \
            __syncthreads();                                                       \
            if (!tid) nvshmem_quiet();                                             \
            __syncthreads();                                                       \
        }                                                                          \
    }

LATENCY_THREADGROUP(warp)
LATENCY_THREADGROUP(block)

#if defined __cplusplus || defined NVSHMEM_HOSTLIB_ONLY
}
#endif

#define DEFINE_TEST_LATENCY(TG)                                                               \
                                                                                              \
    void test_latency##TG(int *data_d, int len, int pe, int iter, MUfunction kernel,          \
                          int threads) {                                                      \
        if (use_cubin) {                                                                      \
            void *arglist[] = {(void *)&data_d, (void *)&len, (void *)&pe, (void *)&iter};    \
            MU_CHECK(muLaunchKernel(kernel, 1, 1, 1, threads, 1, 1, 0, NULL, arglist, NULL)); \
        } else {                                                                              \
            latency_kern##TG<<<1, threads>>>(data_d, len, pe, iter);                          \
        }                                                                                     \
    }

DEFINE_TEST_LATENCY()
DEFINE_TEST_LATENCY(_warp)
DEFINE_TEST_LATENCY(_block)

int main(int argc, char *argv[]) {
    int mype, npes, size;
    int *data_d = NULL;

    read_args(argc, argv);

    int iter = iters;
    int skip = warmup_iters;

    int array_size, i;
    void **h_tables;
    uint64_t *h_size_arr;
    double *h_lat;

    float milliseconds;
    musaEvent_t start, stop;
    MUfunction test_cubin = NULL;
    MUfunction test_cubin_warp = NULL;
    MUfunction test_cubin_block = NULL;

    init_wrapper(&argc, &argv);

    if (use_cubin) {
        init_cumodule(CUMODULE_NAME);
        init_test_case_kernel(&test_cubin, "latency_kern");
        init_test_case_kernel(&test_cubin, "latency_kern_warp");
        init_test_case_kernel(&test_cubin, "latency_kern_block");
    }

    musaEventCreate(&start);
    musaEventCreate(&stop);

    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();

    if (npes != 2) {
        fprintf(stderr, "This test requires exactly two processes \n");
        goto finalize;
    }

    if (use_mmap) {
        data_d = (int *)allocate_mmap_buffer(max_size, mem_handle_type, use_egm, true);
        DEBUG_PRINT("Allocated mmap buffer\n");
    } else {
        data_d = (int *)nvshmem_malloc(max_size);
        DEBUG_PRINT("Allocated nvshmem malloc buffer\n");
        MUSA_CHECK(musaMemset(data_d, 0, max_size));
    }

    array_size = max_size_log;
    alloc_tables(&h_tables, 2, array_size);
    h_size_arr = (uint64_t *)h_tables[0];
    h_lat = (double *)h_tables[1];

    nvshmem_barrier_all();

    MUSA_CHECK(musaDeviceSynchronize());

    i = 0;
    for (size = min_size; size <= max_size; size *= step_factor) {
        if (!mype) {
            int nelems;
            h_size_arr[i] = size;
            nelems = size / sizeof(int);

            test_latency(data_d, nelems, mype, skip, test_cubin, 1);
            musaEventRecord(start);
            test_latency(data_d, nelems, mype, iter, test_cubin, 1);
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
        print_table_basic("shmem_g_latency", "Thread", "size (Bytes)", "latency", "us", '-',
                          h_size_arr, h_lat, i);
    }

    i = 0;
    for (size = min_size; size <= max_size; size *= step_factor) {
        if (!mype) {
            int nelems;
            h_size_arr[i] = size;
            nelems = size / sizeof(int);

            test_latency_warp(data_d, nelems, mype, skip, test_cubin_warp, THREADS_PER_WARP);
            musaEventRecord(start);
            test_latency_warp(data_d, nelems, mype, iter, test_cubin_warp, THREADS_PER_WARP);
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
        print_table_basic("shmem_get_latency", "Warp", "size (Bytes)", "latency", "us", '-',
                          h_size_arr, h_lat, i);
    }

    i = 0;
    for (size = min_size; size <= max_size; size *= step_factor) {
        if (!mype) {
            int nelems;
            h_size_arr[i] = size;
            nelems = size / sizeof(int);

            test_latency_block(data_d, nelems, mype, skip, test_cubin_block, threads_per_block);
            musaEventRecord(start);
            test_latency_block(data_d, nelems, mype, iter, test_cubin_block, threads_per_block);
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
        print_table_basic("shmem_get_latency", "Block", "size (Bytes)", "latency", "us", '-',
                          h_size_arr, h_lat, i);
    }

finalize:

    if (data_d) {
        if (use_mmap) {
            free_mmap_buffer(data_d);
        } else {
            nvshmem_free(data_d);
        }
    }
    free_tables(h_tables, 2);
    finalize_wrapper();

    return 0;
}
