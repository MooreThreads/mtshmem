/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018-2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include "bootstrap_helper.h"
#include "nvshmem.h"
#include "nvshmemx.h"

#define THRESHOLD 42
#define CORRECTION 7

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

__global__ void init(int *input) {
    int index = threadIdx.x;
    input[index] = nvshmem_my_pe();
}

__global__ void init_long_float(long *plong, float *pfloat, int mype) {
    if (threadIdx.x == 0) {
        *plong = (long)mype;
        *pfloat = (float)mype;
    }
}

__global__ void accumulate(int *input, int *partial_sum) {
    int index = threadIdx.x;
    if (0 == index) *partial_sum = 0;
    __syncthreads();
    atomicAdd(partial_sum, input[index]);
}

__global__ void correct_accumulate(int *input, int *partial_sum, int *full_sum) {
    int index = threadIdx.x;
    if (*full_sum > THRESHOLD) {
        input[index] = input[index] - CORRECTION;
    }
    if (0 == index) *partial_sum = 0;
    __syncthreads();
    atomicAdd(partial_sum, input[index]);
}

template <typename T>
static void init_symmetric_scalar(T *ptr, T value, musaStream_t stream) {
    MUSA_CHECK(
        musaMemcpyAsync(ptr, &value, sizeof(T), musaMemcpyHostToDevice, stream));
}

#define FOR_BITWISE_REDUCE_TYPES(FN, OP)     \
    FN(uchar, unsigned char, OP);            \
    FN(ushort, unsigned short, OP);          \
    FN(uint, unsigned int, OP);              \
    FN(ulong, unsigned long, OP);            \
    FN(ulonglong, unsigned long long, OP);   \
    FN(int8, int8_t, OP);                    \
    FN(int16, int16_t, OP);                  \
    FN(int32, int32_t, OP);                  \
    FN(int64, int64_t, OP);                  \
    FN(uint8, uint8_t, OP);                  \
    FN(uint16, uint16_t, OP);                \
    FN(uint32, uint32_t, OP);                \
    FN(uint64, uint64_t, OP);                \
    FN(size, size_t, OP)

#define FOR_STANDARD_REDUCE_TYPES(FN, OP)    \
    FOR_BITWISE_REDUCE_TYPES(FN, OP);        \
    FN(char, char, OP);                      \
    FN(schar, signed char, OP);              \
    FN(short, short, OP);                    \
    FN(int, int, OP);                        \
    FN(long, long, OP);                      \
    FN(longlong, long long, OP);             \
    FN(float, float, OP);                    \
    FN(double, double, OP)

#define FOR_ARITH_REDUCE_TYPES(FN, OP) FOR_STANDARD_REDUCE_TYPES(FN, OP)

int main(int c, char *v[]) {
    int mype, npes, mype_node;
    int *input;
    int *partial_sum, *h_partial_sum;
    int *full_sum, *h_full_sum;
    int input_nelems = 512;
    int to_all_nelems = 1;
    musaStream_t stream;

#ifdef NVSHMEMTEST_MPI_SUPPORT
    bool use_mpi = false;
    char *value = getenv("NVSHMEMTEST_USE_MPI_LAUNCHER");
    if (value) use_mpi = atoi(value);
#endif

#ifdef NVSHMEMTEST_MPI_SUPPORT
    if (use_mpi) {
        nvshmemi_init_mpi(&c, &v);
    } else
        nvshmem_init();
#else
    nvshmem_init();
#endif

    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();
    mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    MUSA_CHECK(musaSetDevice(mype_node));
    MUSA_CHECK(musaStreamCreate(&stream));

    input = (int *)nvshmem_malloc(sizeof(int) * input_nelems);
    partial_sum = (int *)nvshmem_malloc(sizeof(int));
    full_sum = (int *)nvshmem_malloc(sizeof(int));
    long *plong_src = (long *)nvshmem_malloc(sizeof(long));
    long *plong_dst = (long *)nvshmem_malloc(sizeof(long));
    float *pfloat_src = (float *)nvshmem_malloc(sizeof(float));
    float *pfloat_dst = (float *)nvshmem_malloc(sizeof(float));
    MUSA_CHECK(musaMemset(partial_sum, 0, sizeof(int)));
    MUSA_CHECK(musaMemset(full_sum, 0, sizeof(int)));
    MUSA_CHECK(musaMemset(plong_dst, 0, sizeof(long)));
    MUSA_CHECK(musaMemset(pfloat_dst, 0, sizeof(float)));
    h_partial_sum = (int *)malloc(sizeof(int));
    h_full_sum = (int *)malloc(sizeof(int));
    init<<<1, input_nelems, 0, stream>>>(input);
    init_long_float<<<1, 1, 0, stream>>>(plong_src, pfloat_src, mype);

    accumulate<<<1, input_nelems, 0, stream>>>(input, partial_sum);
    MUSA_CHECK(musaMemcpyAsync(h_partial_sum, partial_sum, sizeof(int), musaMemcpyDeviceToHost, stream));
    MUSA_CHECK(musaStreamSynchronize(stream));
    printf("[%d of %d] accumulate partial_sum : %d\n", mype, npes, h_partial_sum[0]);
    nvshmemx_int_sum_reduce_on_stream(NVSHMEM_TEAM_WORLD, full_sum, partial_sum, to_all_nelems,
                                      stream);
    MUSA_CHECK(musaMemcpyAsync(h_full_sum, full_sum, sizeof(int), musaMemcpyDeviceToHost, stream));
    MUSA_CHECK(musaStreamSynchronize(stream));
    printf("[%d of %d] nvshmemx_int_sum_reduce_on_stream full_sum : %d\n", mype, npes, h_full_sum[0]);

    /* P0: more reduce_on_stream type/op for host/stream/coll/rdxn coverage */
    nvshmemx_int_max_reduce_on_stream(NVSHMEM_TEAM_WORLD, full_sum, partial_sum, to_all_nelems, stream);
    nvshmemx_int_min_reduce_on_stream(NVSHMEM_TEAM_WORLD, full_sum, partial_sum, to_all_nelems, stream);
    nvshmemx_long_max_reduce_on_stream(NVSHMEM_TEAM_WORLD, plong_dst, plong_src, 1, stream);
    nvshmemx_float_min_reduce_on_stream(NVSHMEM_TEAM_WORLD, pfloat_dst, pfloat_src, 1, stream);
    MUSA_CHECK(musaStreamSynchronize(stream));

/* Sweep more type/op combinations to improve reduce_on_stream instantiation coverage. */
#define EXERCISE_REDUCE(Name, TYPE, OP)                                                     \
    do {                                                                                    \
        TYPE *src = (TYPE *)nvshmem_malloc(sizeof(TYPE));                                   \
        TYPE *dst = (TYPE *)nvshmem_malloc(sizeof(TYPE));                                   \
        if (!src || !dst) {                                                                 \
            fprintf(stderr, "[%d] reduce alloc failed for %s_%s\n", mype, #Name, #OP);     \
            nvshmem_global_exit(2);                                                         \
        }                                                                                   \
        TYPE src_value = static_cast<TYPE>(mype + 1);                                       \
        TYPE dst_value = static_cast<TYPE>(0);                                              \
        init_symmetric_scalar(src, src_value, stream);                                      \
        init_symmetric_scalar(dst, dst_value, stream);                                      \
        MUSA_CHECK(musaStreamSynchronize(stream));                                           \
        nvshmem_barrier_all();                                                              \
        nvshmemx_##Name##_##OP##_reduce_on_stream(NVSHMEM_TEAM_WORLD, dst, src, 1, stream); \
        MUSA_CHECK(musaStreamSynchronize(stream));                                           \
        nvshmem_barrier_all();                                                              \
        nvshmem_free(dst);                                                                  \
        nvshmem_free(src);                                                                  \
    } while (0)

    FOR_BITWISE_REDUCE_TYPES(EXERCISE_REDUCE, and);
    FOR_BITWISE_REDUCE_TYPES(EXERCISE_REDUCE, or);
    FOR_BITWISE_REDUCE_TYPES(EXERCISE_REDUCE, xor);
    FOR_STANDARD_REDUCE_TYPES(EXERCISE_REDUCE, min);
    FOR_STANDARD_REDUCE_TYPES(EXERCISE_REDUCE, max);
    FOR_ARITH_REDUCE_TYPES(EXERCISE_REDUCE, sum);
    FOR_ARITH_REDUCE_TYPES(EXERCISE_REDUCE, prod);
#undef EXERCISE_REDUCE

    /* P1: sync/barrier on stream for host/coll/barrier coverage */
    nvshmem_sync_all();
    nvshmem_team_sync(NVSHMEM_TEAM_WORLD);
    nvshmemx_sync_all_on_stream(stream);
    nvshmemx_team_sync_on_stream(NVSHMEM_TEAM_WORLD, stream);
    nvshmemx_barrier_all_on_stream(stream);

    correct_accumulate<<<1, input_nelems, 0, stream>>>(input, partial_sum, full_sum);
    MUSA_CHECK(musaStreamSynchronize(stream));

    printf("[%d of %d] run complete \n", mype, npes);

    MUSA_CHECK(musaStreamDestroy(stream));

    nvshmem_free(input);
    nvshmem_free(partial_sum);
    nvshmem_free(full_sum);
    nvshmem_free(plong_src);
    nvshmem_free(plong_dst);
    nvshmem_free(pfloat_src);
    nvshmem_free(pfloat_dst);
    free(h_full_sum);
    free(h_partial_sum);
    nvshmem_finalize();

#ifdef NVSHMEMTEST_MPI_SUPPORT
    if (use_mpi) nvshmemi_finalize_mpi();
#endif
    return 0;
}
