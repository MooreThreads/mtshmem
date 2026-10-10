/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include "nvshmem.h"
#include "nvshmemx.h"

#undef MUSA_CHECK
#define MUSA_CHECK(stmt)                                                          \
    do {                                                                          \
        musaError_t result = (stmt);                                              \
        if (musaSuccess != result) {                                              \
            fprintf(stderr, "[%s:%d] musa failed %s\n", __FILE__, __LINE__,       \
                    musaGetErrorString(result));                                  \
            exit(-1);                                                             \
        }                                                                         \
    } while (0)

template <typename T>
static void init_symmetric_buffer(T *device_ptr, const T *host_ptr, size_t count, musaStream_t stream) {
    MUSA_CHECK(musaMemcpyAsync(device_ptr, host_ptr, sizeof(T) * count, musaMemcpyHostToDevice, stream));
}

template <typename T>
static void exercise_wait_type(const char *name,
                               void (*wait_one)(T *, int, T, musaStream_t),
                               void (*wait_all)(T *, size_t, const int *, int, T, musaStream_t),
                               void (*wait_all_vector)(T *, size_t, const int *, int, T *, musaStream_t),
                               musaStream_t stream, int mype) {
    T scalar_value[1] = {(T)1};
    T all_values[2] = {(T)1, (T)1};
    T vector_values[2] = {(T)1, (T)2};
    T vector_cmp[2] = {(T)1, (T)2};

    T *scalar_buf = (T *)nvshmem_malloc(sizeof(T));
    T *all_buf = (T *)nvshmem_malloc(sizeof(T) * 2);
    T *vector_buf = (T *)nvshmem_malloc(sizeof(T) * 2);
    T *vector_cmp_buf = (T *)nvshmem_malloc(sizeof(T) * 2);
    if (!scalar_buf || !all_buf || !vector_buf || !vector_cmp_buf) {
        fprintf(stderr, "[%d] nvshmem_malloc failed for %s wait test\n", mype, name);
        exit(-1);
    }

    init_symmetric_buffer(scalar_buf, scalar_value, 1, stream);
    init_symmetric_buffer(all_buf, all_values, 2, stream);
    init_symmetric_buffer(vector_buf, vector_values, 2, stream);
    init_symmetric_buffer(vector_cmp_buf, vector_cmp, 2, stream);

    wait_one(scalar_buf, NVSHMEM_CMP_EQ, (T)1, stream);
    wait_all(all_buf, 2, NULL, NVSHMEM_CMP_EQ, (T)1, stream);
    wait_all_vector(vector_buf, 2, NULL, NVSHMEM_CMP_EQ, vector_cmp_buf, stream);

    MUSA_CHECK(musaStreamSynchronize(stream));

    nvshmem_free(scalar_buf);
    nvshmem_free(all_buf);
    nvshmem_free(vector_buf);
    nvshmem_free(vector_cmp_buf);

    if (mype == 0) {
        printf("exercised %s wait-on-stream APIs\n", name);
    }
}

int main(int c, char *v[]) {
    int mype, npes, mype_node;
    uint64_t *sig_per_pe;
    musaStream_t stream;

    nvshmem_init();
    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();
    mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    MUSA_CHECK(musaSetDevice(mype_node));
    MUSA_CHECK(musaStreamCreate(&stream));

    sig_per_pe = (uint64_t *)nvshmem_malloc(sizeof(uint64_t));
    if (!sig_per_pe) {
        fprintf(stderr, "[%d] nvshmem_malloc failed\n", mype);
        nvshmem_finalize();
        return -1;
    }
    MUSA_CHECK(musaMemset(sig_per_pe, 0, sizeof(uint64_t)));

    nvshmemx_quiet_on_stream(stream);

    exercise_wait_type<short>("short", nvshmemx_short_wait_until_on_stream,
                              nvshmemx_short_wait_until_all_on_stream,
                              nvshmemx_short_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<int>("int", nvshmemx_int_wait_until_on_stream,
                            nvshmemx_int_wait_until_all_on_stream,
                            nvshmemx_int_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<long>("long", nvshmemx_long_wait_until_on_stream,
                             nvshmemx_long_wait_until_all_on_stream,
                             nvshmemx_long_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<long long>("longlong", nvshmemx_longlong_wait_until_on_stream,
                                  nvshmemx_longlong_wait_until_all_on_stream,
                                  nvshmemx_longlong_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<unsigned short>("ushort", nvshmemx_ushort_wait_until_on_stream,
                                       nvshmemx_ushort_wait_until_all_on_stream,
                                       nvshmemx_ushort_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<unsigned int>("uint", nvshmemx_uint_wait_until_on_stream,
                                     nvshmemx_uint_wait_until_all_on_stream,
                                     nvshmemx_uint_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<unsigned long>("ulong", nvshmemx_ulong_wait_until_on_stream,
                                      nvshmemx_ulong_wait_until_all_on_stream,
                                      nvshmemx_ulong_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<unsigned long long>("ulonglong", nvshmemx_ulonglong_wait_until_on_stream,
                                           nvshmemx_ulonglong_wait_until_all_on_stream,
                                           nvshmemx_ulonglong_wait_until_all_vector_on_stream, stream,
                                           mype);
    exercise_wait_type<int32_t>("int32", nvshmemx_int32_wait_until_on_stream,
                                nvshmemx_int32_wait_until_all_on_stream,
                                nvshmemx_int32_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<int64_t>("int64", nvshmemx_int64_wait_until_on_stream,
                                nvshmemx_int64_wait_until_all_on_stream,
                                nvshmemx_int64_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<uint32_t>("uint32", nvshmemx_uint32_wait_until_on_stream,
                                 nvshmemx_uint32_wait_until_all_on_stream,
                                 nvshmemx_uint32_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<uint64_t>("uint64", nvshmemx_uint64_wait_until_on_stream,
                                 nvshmemx_uint64_wait_until_all_on_stream,
                                 nvshmemx_uint64_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<size_t>("size", nvshmemx_size_wait_until_on_stream,
                               nvshmemx_size_wait_until_all_on_stream,
                               nvshmemx_size_wait_until_all_vector_on_stream, stream, mype);
    exercise_wait_type<ptrdiff_t>("ptrdiff", nvshmemx_ptrdiff_wait_until_on_stream,
                                  nvshmemx_ptrdiff_wait_until_all_on_stream,
                                  nvshmemx_ptrdiff_wait_until_all_vector_on_stream, stream, mype);

    if (mype == 0) {
        for (int i = 0; i < npes; i++) {
            nvshmemx_signal_op_on_stream(sig_per_pe, 1, NVSHMEM_SIGNAL_SET, i, stream);
            nvshmemx_signal_op_on_stream(sig_per_pe, 1, NVSHMEM_SIGNAL_ADD, i, stream);
        }
    }

    nvshmemx_signal_wait_until_on_stream(sig_per_pe, NVSHMEM_CMP_EQ, 2, stream);

    MUSA_CHECK(musaStreamSynchronize(stream));
    printf("[%d of %d] wait-signal-on-stream done, signal ptr:%lu\n", mype, npes, nvshmem_signal_fetch(sig_per_pe));

    nvshmem_free(sig_per_pe);
    MUSA_CHECK(musaStreamDestroy(stream));
    nvshmem_finalize();
    return 0;
}
