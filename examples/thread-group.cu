/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018-2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>

#include "bootstrap_helper.h"
#include "nvshmem.h"
#include "nvshmemx.h"

#define NTHREADS 512

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

__global__ void distributed_vector_sum(int *x, int *y, int *partial_sum, int *sum,
                                       int use_threadgroup, int mype, int npes) {
    int index = threadIdx.x;
    int nelems = blockDim.x;
    partial_sum[index] = x[index] + y[index];

    if (use_threadgroup) {
        /* all threads realize the entire fcollect operation */
        nvshmemx_int_fcollect_block(NVSHMEM_TEAM_WORLD, sum, partial_sum, nelems);
    } else {
        /* thread 0 realizes the entire fcollect operation */
        if (0 == index) {
            nvshmem_int_fcollect(NVSHMEM_TEAM_WORLD, sum, partial_sum, nelems);
        }
    }
}

int main(int c, char *v[]) {
    int mype, npes, mype_node;
    int *x, *h_x;
    int *y, *h_y;
    int *partial_sum, *h_partial_sum;
    int *sum, *h_sum;
    int use_threadgroup = 1;
    int nthreads = NTHREADS;

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

    npes = nvshmem_n_pes();
    mype = nvshmem_my_pe();
    mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);

    MUSA_CHECK(musaSetDevice(mype_node));

    x = (int *)nvshmem_malloc(sizeof(int) * nthreads);
    y = (int *)nvshmem_malloc(sizeof(int) * nthreads);
    h_x = (int *)malloc(sizeof(int) * nthreads);
    h_y = (int *)malloc(sizeof(int) * nthreads);
    for (size_t i = 0; i < nthreads; i++) {
        h_x[i] = i / (mype + 1);
        h_y[i] = i % (mype + 1);
    }
    MUSA_CHECK(musaMemcpy(x, h_x, sizeof(int) * nthreads, musaMemcpyHostToDevice));
    MUSA_CHECK(musaMemcpy(y, h_y, sizeof(int) * nthreads, musaMemcpyHostToDevice));
    partial_sum = (int *)nvshmem_malloc(sizeof(int) * nthreads);
    sum = (int *)nvshmem_malloc(sizeof(int) * nthreads * npes);
    h_partial_sum = (int *)malloc(sizeof(int) * nthreads);
    h_sum = (int *)malloc(sizeof(int) * nthreads * npes);

    void *args[] = {&x, &y, &partial_sum, &sum, &use_threadgroup, &mype, &npes};
    dim3 dimBlock(nthreads);
    dim3 dimGrid(1);
    nvshmemx_collective_launch((const void *)distributed_vector_sum, dimGrid, dimBlock, args, 0, 0);
    MUSA_CHECK(musaDeviceSynchronize());
    
    MUSA_CHECK(musaMemcpy(h_partial_sum, partial_sum, sizeof(int) * nthreads, musaMemcpyDeviceToHost));
    MUSA_CHECK(musaMemcpy(h_sum, sum, sizeof(int) * nthreads * npes, musaMemcpyDeviceToHost));
    
    int reduce_partial = 0, reduce_sum = 0;
    for (size_t i = 0; i < nthreads; i++) {
        reduce_partial += h_partial_sum[i];
        for (size_t j = 0; j < npes; j++) {
          reduce_sum += h_sum[i + j * nthreads];
        }
        if (h_partial_sum[i] != h_x[i] + h_y[i])
            printf("PE %d error, data[%zu] = %d expected data[%zu] = %d\n", mype, i,
                    h_partial_sum[i], i,h_x[i] + h_y[i]);
    }
    printf("[%d of %d] run complete: reduce_partial:%d reduce_sum:%d\n",
            mype, npes, reduce_partial, reduce_sum);

    nvshmem_free(x);
    nvshmem_free(y);
    nvshmem_free(partial_sum);
    nvshmem_free(sum);
    free(h_x);
    free(h_y);
    free(h_partial_sum);
    free(h_sum);
    
    nvshmem_finalize();
#ifdef NVSHMEMTEST_MPI_SUPPORT
    if (use_mpi) nvshmemi_finalize_mpi();
#endif

    return 0;
}
