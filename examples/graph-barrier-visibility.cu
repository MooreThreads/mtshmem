/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "nvshmem.h"
#include "nvshmemx.h"

#define MUSA_CHECK(stmt)                                                          \
    do {                                                                          \
        musaError_t result = (stmt);                                              \
        if (musaSuccess != result) {                                              \
            fprintf(stderr, "[%s:%d] MUSA error: %s\n", __FILE__, __LINE__,      \
                    musaGetErrorString(result));                                  \
            exit(EXIT_FAILURE);                                                   \
        }                                                                         \
    } while (0)

__global__ void prepare_payload(uint64_t *source, uint64_t *target, int *errors,
                                uint64_t *epoch, size_t words, int mype) {
    if (threadIdx.x == 0) ++(*epoch);
    __syncthreads();

    uint64_t value_prefix = (*epoch << 48) ^ (static_cast<uint64_t>(mype) << 40);
    for (size_t i = threadIdx.x; i < words; i += blockDim.x) {
        source[i] = value_prefix ^ i;
        target[i] = UINT64_MAX;
    }
    if (threadIdx.x == 0) *errors = 0;
}

__global__ void put_payload(uint64_t *target, const uint64_t *source, size_t bytes, int peer) {
    nvshmemx_putmem_nbi_block(target, source, bytes, peer);
}

__global__ void verify_payload(const uint64_t *target, int *errors, const uint64_t *epoch,
                               size_t words, int source_pe) {
    uint64_t value_prefix = (*epoch << 48) ^ (static_cast<uint64_t>(source_pe) << 40);
    for (size_t i = threadIdx.x; i < words; i += blockDim.x) {
        if (target[i] != (value_prefix ^ i)) atomicExch(errors, 1);
    }
}

static int run_case(size_t bytes, int iterations, int mype, int npes, musaStream_t stream,
                    uint64_t *source, uint64_t *target, int *errors, int *reduced_errors,
                    uint64_t *epoch) {
    const int threads = 256;
    const size_t words = bytes / sizeof(uint64_t);
    const int next_pe = (mype + 1) % npes;
    const int previous_pe = (mype + npes - 1) % npes;
    musaGraph_t graph;
    musaGraphExec_t graph_exec;

    MUSA_CHECK(musaMemset(epoch, 0, sizeof(*epoch)));
    MUSA_CHECK(musaStreamBeginCapture(stream, musaStreamCaptureModeGlobal));
    prepare_payload<<<1, threads, 0, stream>>>(source, target, errors, epoch, words, mype);
    nvshmemx_barrier_on_stream(NVSHMEM_TEAM_WORLD, stream);
    put_payload<<<1, threads, 0, stream>>>(target, source, bytes, next_pe);
    nvshmemx_barrier_on_stream(NVSHMEM_TEAM_WORLD, stream);
    verify_payload<<<1, threads, 0, stream>>>(target, errors, epoch, words, previous_pe);
    MUSA_CHECK(musaStreamEndCapture(stream, &graph));
    MUSA_CHECK(musaGraphInstantiate(&graph_exec, graph, NULL, NULL, 0));

    int host_errors = 0;
    for (int iteration = 0; iteration < iterations; ++iteration) {
        MUSA_CHECK(musaGraphLaunch(graph_exec, stream));
        MUSA_CHECK(musaStreamSynchronize(stream));
        nvshmem_int_sum_reduce(NVSHMEM_TEAM_WORLD, reduced_errors, errors, 1);
        MUSA_CHECK(musaMemcpy(&host_errors, reduced_errors, sizeof(host_errors),
                              musaMemcpyDeviceToHost));
        if (host_errors != 0) {
            if (mype == 0) {
                fprintf(stderr, "graph barrier visibility failed: bytes=%zu iteration=%d\n",
                        bytes, iteration);
            }
            break;
        }
    }

    MUSA_CHECK(musaGraphExecDestroy(graph_exec));
    MUSA_CHECK(musaGraphDestroy(graph));
    return host_errors;
}

int main() {
    constexpr size_t max_bytes = 1U << 20;
    int mype, npes, mype_node;
    musaStream_t stream;

    nvshmem_init();
    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();
    mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    MUSA_CHECK(musaSetDevice(mype_node));
    MUSA_CHECK(musaStreamCreate(&stream));

    uint64_t *source = static_cast<uint64_t *>(nvshmem_malloc(max_bytes));
    uint64_t *target = static_cast<uint64_t *>(nvshmem_malloc(max_bytes));
    int *errors = static_cast<int *>(nvshmem_malloc(sizeof(*errors)));
    int *reduced_errors = static_cast<int *>(nvshmem_malloc(sizeof(*reduced_errors)));
    uint64_t *epoch = nullptr;
    MUSA_CHECK(musaMalloc(&epoch, sizeof(*epoch)));
    if (!source || !target || !errors || !reduced_errors) {
        fprintf(stderr, "[%d] symmetric allocation failed\n", mype);
        return EXIT_FAILURE;
    }

    nvshmem_barrier_all();
    int failed = run_case(sizeof(uint64_t), 1000, mype, npes, stream, source, target, errors,
                          reduced_errors, epoch);
    if (!failed) {
        failed = run_case(max_bytes, 100, mype, npes, stream, source, target, errors,
                          reduced_errors, epoch);
    }

    nvshmem_barrier_all();
    MUSA_CHECK(musaFree(epoch));
    nvshmem_free(reduced_errors);
    nvshmem_free(errors);
    nvshmem_free(target);
    nvshmem_free(source);
    MUSA_CHECK(musaStreamDestroy(stream));
    nvshmem_finalize();

    if (!failed && mype == 0) printf("graph barrier visibility passed\n");
    return failed ? EXIT_FAILURE : EXIT_SUCCESS;
}
