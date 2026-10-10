/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * Host-side put/get coverage driver for host/comm/putget.cpp.
 * See COPYRIGHT for license information.
 */
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "nvshmem.h"
#include "nvshmemx.h"
#include "host/nvshmem_api.h"

#undef MUSA_CHECK
#define MUSA_CHECK(stmt)                                                          \
    do {                                                                          \
        musaError_t result = (stmt);                                              \
        if (musaSuccess != result) {                                              \
            fprintf(stderr, "[%s:%d] MUSA failed: %s\n", __FILE__, __LINE__,       \
                    musaGetErrorString(result));                                 \
            exit(-1);                                                             \
        }                                                                         \
    } while (0)

__global__ void put_nbi_kernel(int *remote_dest, const int *local_src, int pe) {
    nvshmem_int_put_nbi(remote_dest, local_src, 1, pe);
    nvshmem_quiet();
}

static void init_symmetric_ints(int *ptr, const int *src, size_t count) {
    MUSA_CHECK(musaMemcpy(ptr, src, count * sizeof(int), musaMemcpyHostToDevice));
}

#define FOR_STANDARD_PUT_TYPES(FN)          \
    FN(float, float);                       \
    FN(double, double);                     \
    FN(char, char);                         \
    FN(short, short);                       \
    FN(schar, signed char);                 \
    FN(int, int);                           \
    FN(long, long);                         \
    FN(longlong, long long);                \
    FN(uchar, unsigned char);               \
    FN(ushort, unsigned short);             \
    FN(uint, unsigned int);                 \
    FN(ulong, unsigned long);               \
    FN(ulonglong, unsigned long long);      \
    FN(int8, int8_t);                       \
    FN(int16, int16_t);                     \
    FN(int32, int32_t);                     \
    FN(int64, int64_t);                     \
    FN(uint8, uint8_t);                     \
    FN(uint16, uint16_t);                   \
    FN(uint32, uint32_t);                   \
    FN(uint64, uint64_t);                   \
    FN(size, size_t);                       \
    FN(ptrdiff, ptrdiff_t);

struct HostRmaBuffers {
#define DECLARE_HOST_RMA_VALUE(Name, TYPE) TYPE Name##_value
    FOR_STANDARD_PUT_TYPES(DECLARE_HOST_RMA_VALUE)
#undef DECLARE_HOST_RMA_VALUE
    int put_value;
    int recv;
    int host_iput_src[4];
    int host_iget_dst[4];
    int put_stream_value;
    int stream_get;
    int stream_getmem[4];
    int stream_get_nbi;
    int stream_iget_dst[4];
    int stream_signal_payload;
    int host_getmem[4];
    int host_get_nbi;
};

int main(int argc, char **argv) {
    bool basic_transport = argc > 1 && strcmp(argv[1], "--basic-transport") == 0;

    nvshmem_init();
    int mype = nvshmem_my_pe();
    int npes = nvshmem_n_pes();
    if (npes < 2) {
        if (mype == 0) fprintf(stderr, "host-put-get requires at least 2 PEs\n");
        nvshmem_finalize();
        return 1;
    }
    int peer = (mype + 1) % npes;

    int mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    MUSA_CHECK(musaSetDevice(mype_node));

    musaStream_t stream;
    MUSA_CHECK(musaStreamCreate(&stream));

    int *sym = (int *)nvshmem_malloc(sizeof(int));
    int *sym_vec = (int *)nvshmem_malloc(4 * sizeof(int));
    uint64_t *sig = (uint64_t *)nvshmem_malloc(sizeof(uint64_t));
    if (!sym || !sym_vec || !sig) {
        if (sym) nvshmem_free(sym);
        if (sym_vec) nvshmem_free(sym_vec);
        if (sig) nvshmem_free(sig);
        MUSA_CHECK(musaStreamDestroy(stream));
        nvshmem_finalize();
        return 1;
    }

    HostRmaBuffers *host_rma = NULL;
    MUSA_CHECK(musaHostAlloc((void **)&host_rma, sizeof(*host_rma), musaHostAllocMapped));
    if (nvshmemx_buffer_register(host_rma, sizeof(*host_rma)) != 0) {
        fprintf(stderr, "[%d] nvshmemx_buffer_register failed for host RMA buffers\n", mype);
        MUSA_CHECK(musaFreeHost(host_rma));
        nvshmem_free(sig);
        nvshmem_free(sym_vec);
        nvshmem_free(sym);
        MUSA_CHECK(musaStreamDestroy(stream));
        nvshmem_finalize();
        return 1;
    }

    int local_value = mype;
    int vec_init[4] = {mype, mype + 10, mype + 20, mype + 30};
    uint64_t sig_init = 0;
    MUSA_CHECK(musaMemcpy(sym, &local_value, sizeof(int), musaMemcpyHostToDevice));
    init_symmetric_ints(sym_vec, vec_init, 4);
    MUSA_CHECK(musaMemcpy(sig, &sig_init, sizeof(sig_init), musaMemcpyHostToDevice));

    nvshmem_barrier_all();

    /* Sweep standard typed put + put_on_stream wrappers to raise function coverage. */
    if (!basic_transport) {
#define EXERCISE_PUT_TYPE(Name, TYPE)                                                     \
    do {                                                                                  \
        TYPE *typed_sym = (TYPE *)nvshmem_malloc(sizeof(TYPE));                           \
        if (!typed_sym) {                                                                 \
            fprintf(stderr, "[%d] nvshmem_malloc failed for " #Name "\n", mype);         \
            nvshmem_global_exit(2);                                                       \
        }                                                                                 \
        TYPE zero = (TYPE)0;                                                              \
        TYPE *typed_value = &host_rma->Name##_value;                                      \
        *typed_value = static_cast<TYPE>(mype + 1);                                       \
        MUSA_CHECK(musaMemcpy(typed_sym, &zero, sizeof(TYPE), musaMemcpyHostToDevice));   \
        nvshmem_barrier_all();                                                            \
        nvshmem_##Name##_put(typed_sym, typed_value, 1, peer);                            \
        nvshmem_quiet();                                                                  \
        nvshmem_barrier_all();                                                            \
        nvshmemx_##Name##_put_on_stream(typed_sym, typed_value, 1, peer, stream);         \
        MUSA_CHECK(musaStreamSynchronize(stream));                                        \
        nvshmem_barrier_all();                                                            \
        nvshmem_free(typed_sym);                                                          \
    } while (0)
    FOR_STANDARD_PUT_TYPES(EXERCISE_PUT_TYPE);
#undef EXERCISE_PUT_TYPE
    }

    /* Blocking put / get / p */
    host_rma->put_value = 100 + mype;
    nvshmem_int_put(sym, &host_rma->put_value, 1, peer);
    nvshmem_quiet();
    host_rma->recv = -1;
    nvshmem_int_get(&host_rma->recv, sym, 1, peer);
    nvshmem_barrier_all();
    if (host_rma->recv != host_rma->put_value) {
        fprintf(stderr, "[%d] unexpected blocking get value: %d (expected %d)\n", mype,
                host_rma->recv, host_rma->put_value);
        nvshmem_global_exit(4);
    }

    int p_value = 200 + mype;
    nvshmem_int_p(sym, p_value, peer);
    nvshmem_barrier_all();
    if (!basic_transport) {
        /* Strided host iput / iget exercise the 2D async path. */
        for (int i = 0; i < 4; i++) {
            host_rma->host_iput_src[i] = mype + i + 1;
            host_rma->host_iget_dst[i] = -1;
        }
        init_symmetric_ints(sym_vec, vec_init, 4);
        nvshmem_barrier_all();
        nvshmem_int_iput(sym_vec, host_rma->host_iput_src, 2, 2, 2, peer);
        nvshmem_barrier_all();
        nvshmem_int_iget(host_rma->host_iget_dst, sym_vec, 1, 2, 2, peer);
        nvshmem_barrier_all();

        /* Device put_nbi + quiet */
        int *d_src = NULL;
        MUSA_CHECK(musaMalloc(&d_src, sizeof(int)));
        MUSA_CHECK(
            musaMemcpy(d_src, &host_rma->put_value, sizeof(int), musaMemcpyHostToDevice));
        nvshmem_barrier_all();
        put_nbi_kernel<<<1, 1>>>(sym, d_src, peer);
        MUSA_CHECK(musaDeviceSynchronize());
        nvshmem_barrier_all();
        MUSA_CHECK(musaFree(d_src));

        /* Stream RMA variants hit async, signal, get, and NBI helper paths. */
        host_rma->put_stream_value = 300 + mype;
        host_rma->stream_get = -1;
        host_rma->stream_get_nbi = -1;
        host_rma->stream_signal_payload = 400 + mype;
        for (int i = 0; i < 4; i++) {
            host_rma->stream_getmem[i] = -1;
            host_rma->stream_iget_dst[i] = -1;
        }
        uint64_t expected_sig = 2;
        sig_init = 0;
        MUSA_CHECK(musaMemcpy(sig, &sig_init, sizeof(sig_init), musaMemcpyHostToDevice));
        init_symmetric_ints(sym_vec, vec_init, 4);
        nvshmem_barrier_all();
        nvshmemx_int_put_on_stream(sym, &host_rma->put_stream_value, 1, peer, stream);
        nvshmemx_int_put_nbi_on_stream(sym, &host_rma->put_stream_value, 1, peer, stream);
        nvshmemx_int_iput_on_stream(sym_vec, host_rma->host_iput_src, 2, 2, 2, peer, stream);
        nvshmemx_int_put_signal_on_stream(sym, &host_rma->stream_signal_payload, 1, sig, 1,
                                          NVSHMEM_SIGNAL_SET, peer, stream);
        nvshmemx_int_put_signal_nbi_on_stream(sym, &host_rma->stream_signal_payload, 1, sig, 1,
                                              NVSHMEM_SIGNAL_ADD, peer, stream);
        nvshmemx_int_get_on_stream(&host_rma->stream_get, sym, 1, peer, stream);
        nvshmemx_getmem_on_stream(host_rma->stream_getmem, sym_vec, 2 * sizeof(int), peer, stream);
        nvshmemx_int_iget_on_stream(host_rma->stream_iget_dst, sym_vec, 1, 2, 2, peer, stream);
        nvshmemx_int_get_nbi_on_stream(&host_rma->stream_get_nbi, sym, 1, peer, stream);
        MUSA_CHECK(musaStreamSynchronize(stream));
        nvshmem_barrier_all();

        uint64_t local_sig = 0;
        MUSA_CHECK(musaMemcpy(&local_sig, sig, sizeof(local_sig), musaMemcpyDeviceToHost));
        if (local_sig != expected_sig) {
            fprintf(stderr, "[%d] unexpected signal value: %llu\n", mype,
                    (unsigned long long)local_sig);
            nvshmem_global_exit(3);
        }
    }

    /* Blocking and NBI getmem/get_nbi complete on host-side paths. */
    host_rma->host_get_nbi = -1;
    for (int i = 0; i < 4; i++) host_rma->host_getmem[i] = -1;
    nvshmem_getmem(host_rma->host_getmem, sym_vec, 2 * sizeof(int), peer);
    nvshmem_int_get_nbi(&host_rma->host_get_nbi, sym, 1, peer);
    nvshmem_getmem_nbi(host_rma->host_getmem + 2, sym_vec + 2, 2 * sizeof(int), peer);
    nvshmem_quiet();
    nvshmem_barrier_all();

    if (nvshmemx_buffer_unregister(host_rma) != 0) {
        fprintf(stderr, "[%d] nvshmemx_buffer_unregister failed for host RMA buffers\n", mype);
        nvshmem_global_exit(5);
    }
    MUSA_CHECK(musaFreeHost(host_rma));
    MUSA_CHECK(musaStreamDestroy(stream));
    nvshmem_free(sig);
    nvshmem_free(sym_vec);
    nvshmem_free(sym);
    nvshmem_finalize();
    return 0;
}
