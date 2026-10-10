/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2026-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2024, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/* This example performs an allreduce operation using ring algorithm when
   GPUs are connected via remote interconect like IB/RoCE/EFA, etc.
   It does ring reduce followed by ring broadcast. We use single threaded put_signal API
   as single thread is sufficient for remote transfers. The example is expected
   to be performant only when GPUs are connected via remote interconnect. */

#include <stdio.h>
#include <stdint.h>
#include <musa.h>
#include <nvshmem.h>
#include <nvshmemx.h>
#include <unistd.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#undef MUSA_CHECK
#define MUSA_CHECK(stmt)                                                          \
    do {                                                                          \
        musaError_t result = (stmt);                                              \
        if (musaSuccess != result) {                                              \
            fprintf(stderr, "[%s:%d] musa failed with %s \n", __FILE__, __LINE__, \
                    musaGetErrorString(result));                                  \
            exit(-1);                                                             \
        }                                                                         \
    } while (0)

/* atol() + optional scaled suffix recognition: 1K, 2M, 3G, 1T */
static inline int atol_scaled(const char *str, size_t *out) {
    int scale, n;
    double p = -1.0;
    char f;
    n = sscanf(str, "%lf%c", &p, &f);

    if (n == 2) {
        switch (f) {
            case 'k':
            case 'K':
                scale = 10;
                break;
            case 'm':
            case 'M':
                scale = 20;
                break;
            case 'g':
            case 'G':
                scale = 30;
                break;
            case 't':
            case 'T':
                scale = 40;
                break;
            default:
                return 1;
        }
    } else if (p < 0) {
        return 1;
    } else
        scale = 0;

    *out = (size_t)ceil(p * (1lu << scale));
    return 0;
}

size_t min_size = 1024 * 1024 * 32;
size_t max_size = min_size * 16;
size_t num_blocks = 32;
size_t threads_per_block = 512;
size_t iters = 4;
size_t warmup_iters = 1;
size_t step_factor = 2;
size_t chunk_size = 262144;

// perform Allreduce using ring
__global__ void ring_reduce(int *dst, const int *src, size_t nreduce, uint64_t *signal,
                            size_t chunk_size) {
    int mype = nvshmem_my_pe();
    int npes = nvshmem_n_pes();
    int peer = (mype + 1) % npes;

    int thread_id = threadIdx.x;
    int num_threads = blockDim.x;
    int num_blocks = gridDim.x;
    int block_idx = blockIdx.x;
    size_t elems_per_block = nreduce / num_blocks;

    // Change src, dst, nreduce, signal to what this block is going to process
    // Each CTA will work independently
    if (elems_per_block * (blockIdx.x + 1) > nreduce) return;
    src = src + block_idx * elems_per_block;
    dst = dst + block_idx * elems_per_block;
    nreduce = elems_per_block;
    signal = signal + block_idx;

    size_t chunk_elems = chunk_size / sizeof(int);
    size_t num_chunks = nreduce / chunk_elems;

    // reduce phase
    for (size_t chunk = 0; chunk < num_chunks; chunk++) {
        if (mype != 0) {
            if (thread_id == 0) nvshmem_signal_wait_until(signal, NVSHMEM_CMP_GE, chunk + 1);

            __syncthreads();
            for (size_t i = thread_id; i < chunk_elems; i += num_threads) {
                dst[i] = dst[i] + src[i];
            }
            __syncthreads();
        }
        if (thread_id == 0)
            nvshmem_int_put_signal_nbi(dst, (mype == 0) ? src : dst, chunk_elems, signal, 1,
                                       NVSHMEM_SIGNAL_ADD, peer);
        src = src + chunk_elems;
        dst = dst + chunk_elems;
    }

    // Broadcast phase
    dst = dst - num_chunks * chunk_elems;
    if (thread_id == 0) {
        for (size_t chunk = 0; chunk < num_chunks; chunk++) {
            if (mype < npes - 1) {  // Last pe already has the final result
                nvshmem_signal_wait_until(signal, NVSHMEM_CMP_GE,
                                          (mype == 0) ? chunk + 1 : num_chunks + chunk + 1);
            }
            if (mype < npes - 2)
                nvshmem_int_put_signal_nbi(dst, dst, chunk_elems, signal, 1, NVSHMEM_SIGNAL_ADD,
                                           peer);
            dst = dst + chunk_elems;
        }
        *signal = 0;  // reset for next iteration
    }
}

int main(int argc, char **argv) {
    int c;
    while ((c = getopt(argc, argv, "b:e:f:n:w:c:t:m:")) != -1) {
        switch (c) {
            case 'b':
                atol_scaled(optarg, &min_size);
                break;
            case 'e':
                atol_scaled(optarg, &max_size);
                break;
            case 'f':
                atol_scaled(optarg, &step_factor);
                break;
            case 'n':
                atol_scaled(optarg, &iters);
                break;
            case 'w':
                atol_scaled(optarg, &warmup_iters);
                break;
            case 'c':
                atol_scaled(optarg, &num_blocks);
                break;
            case 't':
                atol_scaled(optarg, &threads_per_block);
                break;
            case 'm':
                atol_scaled(optarg, &chunk_size);
                break;
            case '?':
                if (optopt == 'c')
                    fprintf(stderr, "Option -%c requires an argument.\n", optopt);
                else if (isprint(optopt))
                    fprintf(stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf(stderr, "Unknown option character `\\x%x'.\n", optopt);
                return 1;
            default:
                abort();
        }
    }
    size_t min_ints = min_size / sizeof(int);
    assert(min_ints % num_blocks == 0);

    nvshmem_init();

    int mype = nvshmem_my_pe();
    int npes = nvshmem_n_pes();
    int mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    musaStream_t stream;
    musaEvent_t start, stop;

    MUSA_CHECK(musaSetDevice(mype_node));
    MUSA_CHECK(musaEventCreate(&start));
    MUSA_CHECK(musaEventCreate(&stop));
    MUSA_CHECK(musaStreamCreate(&stream));

    size_t max_ints = max_size / sizeof(int);
    int *dst = (int *)nvshmem_malloc(max_size);
    int *src = (int *)nvshmem_malloc(max_size);
    int *data_h = (int *)malloc(max_size);
    uint64_t *signal = (uint64_t *)nvshmem_calloc(num_blocks, sizeof(uint64_t));
    dim3 gridDim(num_blocks), blockDim(threads_per_block);

    for (size_t i = 0; i < max_ints; i++) data_h[i] = i;

    MUSA_CHECK(musaMemcpyAsync(src, data_h, max_size, musaMemcpyHostToDevice, stream));
    nvshmemx_barrier_all_on_stream(stream);

    for (size_t size = min_size; size <= max_size; size *= step_factor) {
        size_t num_ints = size / sizeof(int);
        void *args[] = {&dst, &src, &num_ints, &signal, &chunk_size};

        // do warmup
        for (size_t i = 0; i < warmup_iters; i++) {
            nvshmemx_collective_launch((const void *)ring_reduce, gridDim, blockDim, args, 0,
                                       stream);
            nvshmemx_barrier_all_on_stream(stream);
        }
        MUSA_CHECK(musaStreamSynchronize(stream));

        // main loop
        MUSA_CHECK(musaEventRecord(start, stream));
        for (size_t i = 0; i < iters; i++) {
            nvshmemx_collective_launch((const void *)ring_reduce, gridDim, blockDim, args, 0,
                                       stream);
            nvshmemx_barrier_all_on_stream(stream);
        }
        MUSA_CHECK(musaEventRecord(stop, stream));

        MUSA_CHECK(musaStreamSynchronize(stream));
        if (!mype) {
            float ms;
            MUSA_CHECK(musaEventElapsedTime(&ms, start, stop));
            printf("%zuB \t %fms\n", size, ms / iters);
        }

        // validate output
        MUSA_CHECK(musaMemcpy(data_h, dst, size, musaMemcpyDeviceToHost));
        for (size_t i = 0; i < num_ints; i++) {
            if (data_h[i] != (int)i * npes)
                printf("PE %d error, data[%zu] = %d expected data[%zu] = %d\n", mype, i, data_h[i],
                       i, (int)i * npes);
        }
    }

    MUSA_CHECK(musaEventDestroy(start));
    MUSA_CHECK(musaEventDestroy(stop));
    nvshmem_free(dst);
    nvshmem_free(src);
    nvshmem_free(signal);
    free(data_h);

    nvshmem_finalize();
    return 0;
}
