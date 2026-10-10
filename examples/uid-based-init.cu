/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018-2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include "mpi.h"
#include "nvshmem.h"
#include "nvshmemx.h"

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

#define MPI_CHECK(stmt)                                                                         \
    do {                                                                                        \
        int result = (stmt);                                                                    \
        if (MPI_SUCCESS != result) {                                                            \
            fprintf(stderr, "[%s:%d] MPI failed with error %d \n", __FILE__, __LINE__, result); \
            exit(-1);                                                                           \
        }                                                                                       \
    } while (0)

__global__ void simple_shift(int *target, int mype, int npes) {
    int peer = (mype + 1) % npes;
    nvshmem_int_p(target, mype, peer);
}

int main(int c, char *v[]) {
    int *target;
    int rank, nranks;
    nvshmemx_init_attr_t attr = NVSHMEMX_INIT_ATTR_INITIALIZER;
    nvshmemx_uniqueid_t id = NVSHMEMX_UNIQUEID_INITIALIZER;
    int mype, npes, mype_node;

    MPI_CHECK(MPI_Init(&c, &v));
    MPI_CHECK(MPI_Comm_rank(MPI_COMM_WORLD, &rank));
    MPI_CHECK(MPI_Comm_size(MPI_COMM_WORLD, &nranks));

    if (rank == 0) {
        nvshmemx_get_uniqueid(&id);
    }

    MPI_Bcast(&id, sizeof(nvshmemx_uniqueid_t), MPI_UINT8_T, 0, MPI_COMM_WORLD);
    nvshmemx_set_attr_uniqueid_args(rank, nranks, &id, &attr);
    nvshmemx_init_attr(NVSHMEMX_INIT_WITH_UNIQUEID, &attr);
    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();
    mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);

    // application picks the device each PE will use
    MUSA_CHECK(musaSetDevice(mype_node));
    target = (int *)nvshmem_malloc(sizeof(int));

    simple_shift<<<1, 1>>>(target, mype, npes);
    MUSA_CHECK(musaDeviceSynchronize());
    int msg;
    MUSA_CHECK(musaMemcpy(&msg, target, sizeof(int), musaMemcpyDeviceToHost));
    printf("[%d of %d] run complete: received message %d \n", mype, npes, msg);

    nvshmem_free(target);

    nvshmem_finalize();
    MPI_CHECK(MPI_Finalize());
    return 0;
}
