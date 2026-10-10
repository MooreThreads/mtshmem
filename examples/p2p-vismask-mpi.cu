/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * Coverage: p2p can_reach_peer !found branch (p2p.cpp).
 * Each process sets MUSA_VISIBLE_DEVICES=rank and NVSHMEM_DISABLE_MUSA_VMM=1
 * before nvshmem init, so each PE sees only one GPU; peer PCIe id is not in
 * local device list -> !found, then MTML path or VMM WARN path.
 */
#include <stdio.h>
#include <stdlib.h>
#include "mpi.h"
#include "nvshmem.h"
#include "nvshmemx.h"

#undef MUSA_CHECK
#define MUSA_CHECK(stmt)                                                          \
    do {                                                                          \
        musaError_t result = (stmt);                                              \
        if (musaSuccess != result) {                                              \
            fprintf(stderr, "[%s:%d] MUSA failed with %s\n", __FILE__, __LINE__,  \
                    musaGetErrorString(result));                                  \
            exit(-1);                                                             \
        }                                                                         \
    } while (0)

__global__ void simple_shift(int *destination) {
    int mype = nvshmem_my_pe();
    int npes = nvshmem_n_pes();
    int peer = (mype + 1) % npes;
    nvshmem_int_p(destination, mype, peer);
}

int main(int argc, char *argv[]) {
    int rank, nranks;
    char rank_str[16];
    MPI_Comm mpi_comm = MPI_COMM_WORLD;
    nvshmemx_init_attr_t attr = NVSHMEMX_INIT_ATTR_INITIALIZER;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nranks);

    /* Before any MUSA/NVSHMEM init: restrict this process to one GPU (rank).
     * So each PE sees only its own GPU -> peer not in p2p_state->pcie_ids -> !found. */
    (void)snprintf(rank_str, sizeof(rank_str), "%d", rank);
    setenv("MUSA_VISIBLE_DEVICES", rank_str, 1);

    attr.mpi_comm = &mpi_comm;
    nvshmemx_init_attr(NVSHMEMX_INIT_WITH_MPI_COMM, &attr);

    /* With MUSA_VISIBLE_DEVICES=rank, this process sees only one GPU, renumbered as 0 */
    MUSA_CHECK(musaSetDevice(0));

    musaStream_t stream;
    MUSA_CHECK(musaStreamCreate(&stream));
    int *destination = (int *)nvshmem_malloc(sizeof(int));

    simple_shift<<<1, 1, 0, stream>>>(destination);
    nvshmemx_barrier_all_on_stream(stream);
    int msg = -1;
    MUSA_CHECK(musaMemcpyAsync(&msg, destination, sizeof(int), musaMemcpyDeviceToHost, stream));
    MUSA_CHECK(musaStreamSynchronize(stream));

    printf("%d: received message %d\n", nvshmem_my_pe(), msg);

    nvshmem_free(destination);
    nvshmem_finalize();
    MPI_Finalize();
    return 0;
}
