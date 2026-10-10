/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2020, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <stdint.h>
#include <musa.h>
#include <nvshmem.h>
#include <nvshmemx.h>

__global__ void ring_bcast(int *data, size_t nelem, int root, uint64_t *psync) {
    int mype = nvshmem_my_pe();
    int npes = nvshmem_n_pes();
    int peer = (mype + 1) % npes;

    if (mype == root) *psync = 1;

    nvshmem_signal_wait_until(psync, NVSHMEM_CMP_NE, 0);

    if (mype == npes - 1) return;

    nvshmem_int_put(data, data, nelem, peer);
    nvshmem_fence();
    nvshmemx_signal_op(psync, 1, NVSHMEM_SIGNAL_SET, peer);

    *psync = 0;
}

int main(void) {
    size_t data_len = 32;
    musaStream_t stream;

    nvshmem_init();

    int mype = nvshmem_my_pe();
    int mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);

    musaSetDevice(mype_node);
    musaStreamCreate(&stream);

    int *data = (int *)nvshmem_malloc(sizeof(int) * data_len);
    int *data_h = (int *)malloc(sizeof(int) * data_len);
    uint64_t *psync = (uint64_t *)nvshmem_calloc(1, sizeof(uint64_t));

    for (size_t i = 0; i < data_len; i++) data_h[i] = mype + i;

    musaMemcpyAsync(data, data_h, sizeof(int) * data_len, musaMemcpyHostToDevice, stream);

    int root = 0;
    dim3 gridDim(1), blockDim(1);
    void *args[] = {&data, &data_len, &root, &psync};

    nvshmemx_barrier_all_on_stream(stream);
    nvshmemx_collective_launch((const void *)ring_bcast, gridDim, blockDim, args, 0, stream);
    nvshmemx_barrier_all_on_stream(stream);
    musaMemcpyAsync(data_h, data, sizeof(int) * data_len, musaMemcpyDeviceToHost, stream);

    musaStreamSynchronize(stream);

    for (size_t i = 0; i < data_len; i++) {
        if (data_h[i] != (int)i)
            printf("PE %d error, data[%zu] = %d expected data[%zu] = %d\n", mype, i, data_h[i], i,
                   (int)i);
    }

    nvshmem_free(data);
    nvshmem_free(psync);
    free(data_h);

    nvshmem_finalize();
    return 0;
}
