/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2026-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

 #include <stdio.h>
 #include "nvshmem.h"
 #include "nvshmemx.h"
 
 #ifdef NVSHMEMTEST_MPI_SUPPORT
 #include "mpi.h"
 #endif
 
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
 
 #define NVSHMEM_CHECK(stmt)                                                                \
     do {                                                                                   \
         int result = (stmt);                                                               \
         if (NVSHMEMX_SUCCESS != result) {                                                  \
             fprintf(stderr, "[%s:%d] nvshmem failed with error %d \n", __FILE__, __LINE__, \
                     result);                                                               \
             exit(-1);                                                                      \
         }                                                                                  \
     } while (0)
 
 #define CALL_ALLTOALL(TYPENAME, TYPE, TG_PRE, THREADGROUP, THREAD_COMP, ELEM_COMP)                       \
     __global__ void test_##TYPENAME##_alltoall_call_kern##THREADGROUP(                                   \
         nvshmem_team_t team, TYPE *dest, const TYPE *source, int nelems, int mype, int* resultflag) {    \
         if (!blockIdx.x && (threadIdx.x < THREAD_COMP) && (nelems < ELEM_COMP)) {                        \
            nvshmem##TG_PRE##_##TYPENAME##_alltoall##THREADGROUP(team, dest, source, nelems);             \
         }                                                                                                \
         if (*resultflag && !blockIdx.x && !threadIdx.x) {                                                \
            int mype = nvshmem_my_pe();                                                                   \
            int npes = nvshmem_n_pes();                                                                   \
            for (int i = 0; i < npes; i++) {                                                              \
                for (int j = 0; j < nelems; j++) {                                                        \
                    if (dest[i * nelems + j] != i) {                                                      \
                        *resultflag = 0;                                                                  \
                    }                                                                                     \
                }                                                                                         \
            }                                                                                             \
         }                                                                                                \
     }
 
 CALL_ALLTOALL(int32, int32_t, , , 1, 512);
 CALL_ALLTOALL(int64, int64_t, , , 1, 512);
 CALL_ALLTOALL(int32, int32_t, x, _warp, warpSize, 4096);
 CALL_ALLTOALL(int64, int64_t, x, _warp, warpSize, 4096);
 CALL_ALLTOALL(int32, int32_t, x, _block, INT_MAX, INT_MAX);
 CALL_ALLTOALL(int64, int64_t, x, _block, INT_MAX, INT_MAX);

 int main(int c, char *v[]) {
    int mype, npes, mype_node;

#ifdef NVSHMEMTEST_MPI_SUPPORT
    bool use_mpi = false;
    char *value = getenv("NVSHMEMTEST_USE_MPI_LAUNCHER");
    if (value) use_mpi = atoi(value);
#endif

#ifdef NVSHMEMTEST_MPI_SUPPORT
    if (use_mpi) {
        MPI_Init(&c, &v);
        int rank, nranks;
        MPI_Comm_rank(MPI_COMM_WORLD, &rank);
        MPI_Comm_size(MPI_COMM_WORLD, &nranks);
        MPI_Comm mpi_comm = MPI_COMM_WORLD;

        nvshmemx_init_attr_t attr = NVSHMEMX_INIT_ATTR_INITIALIZER;
        attr.mpi_comm = &mpi_comm;
        nvshmemx_init_attr(NVSHMEMX_INIT_WITH_MPI_COMM, &attr);
    } else
        nvshmem_init();
#else
    nvshmem_init();
#endif

    mype = nvshmem_my_pe();
    npes = nvshmem_n_pes();
    mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);

    // application picks the device each PE will use
    MUSA_CHECK(musaSetDevice(mype_node));

    int64_t *h_buffer, *d_buffer;
    int num_elems = 4;

    for (int i = 1; i < c; i++) {
        if (strcmp(v[i], "--num_elems") == 0 && i + 1 < c) {
            int input_elems = atoi(v[i + 1]);

            if (input_elems > 0 && (input_elems & (input_elems - 1)) == 0) {
                num_elems = input_elems;
                if (!mype) {
                    printf("Setting num_elems to %d (2^%d)\n", num_elems, (int)log2(num_elems));
                }
            } else {
                fprintf(stderr, "Error: --num_elems must be a power of 2, got %d\n", input_elems);
                fprintf(stderr, "Valid values: 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, ...\n");
                return -1;
            }
            i++;
        }
    }

    int64_t alloc_size = (num_elems * npes * 2) * sizeof(int64_t);

    MUSA_CHECK(musaHostAlloc(&h_buffer, alloc_size, musaHostAllocDefault));
    memset(h_buffer, 0, alloc_size);

    int64_t* h_source = (int64_t *)h_buffer;
    int64_t* h_dest = (int64_t *)&h_source[num_elems * npes];
    for (int i = 0; i < num_elems * npes; i++) {
        h_source[i] = mype;
    }

    d_buffer = (int64_t *)nvshmem_malloc(alloc_size);
    int64_t* d_source = (int64_t *)d_buffer;
    int64_t* d_dest = (int64_t *)&d_source[num_elems * npes];

    MUSA_CHECK(musaMemcpyAsync(d_source, h_source, (sizeof(int64_t) * num_elems * npes),
                               musaMemcpyHostToDevice, 0));
    MUSA_CHECK(musaMemcpyAsync(d_dest, h_dest, (sizeof(int64_t) * num_elems * npes),
                               musaMemcpyHostToDevice, 0));
    MUSA_CHECK(musaDeviceSynchronize());

    int *resultflag;
    MUSA_CHECK(musaHostAlloc(&resultflag, sizeof(int), musaHostAllocDefault));
    *resultflag = true;

    nvshmem_team_t team = NVSHMEM_TEAM_WORLD;
    void *args_1[] = {&team, &d_dest, &d_source, &num_elems, &mype, &resultflag};
    NVSHMEM_CHECK(nvshmemx_collective_launch((const void *)test_int64_alltoall_call_kern_block,
                                             1, 256, args_1, 0, 0));
    MUSA_CHECK(musaDeviceSynchronize());

    MUSA_CHECK(musaMemcpyAsync(h_source, d_source, (sizeof(int64_t) * num_elems * npes),
                               musaMemcpyDeviceToHost, 0));
    MUSA_CHECK(musaMemcpyAsync(h_dest, d_dest, (sizeof(int64_t) * num_elems * npes),
                               musaMemcpyDeviceToHost, 0));
    MUSA_CHECK(musaDeviceSynchronize());

    bool success = true;
    int faultIdx = -1;
    int i = 0;
    for (; i < npes; i++) {
        for (int j = 0; j < num_elems; j++) {
            if (h_dest[i * num_elems + j] != i) {
                success = false;
                faultIdx = i * num_elems + j;
                break;
            }
        }
        if (!success) break;
    }
    if (success) {
        if (num_elems <= 8) {
            char buffer[1024];
            int pos = 0;
            pos += snprintf(buffer + pos, sizeof(buffer) - pos, "results on device [%d] is", mype);
            for (int i = 0; i < num_elems * npes; i++) {
                pos += snprintf(buffer + pos, sizeof(buffer) - pos, " %ld", h_dest[i]);
            }
            pos += snprintf(buffer + pos, sizeof(buffer) - pos, " , device result check: %s", *resultflag ? "passed" : "failed");
            printf("%s\n", buffer);
        } else {
            printf("results check passed on device [%d], device result check: %s\n", mype, *resultflag ? "passed" : "failed");
        }
    } else {
        printf("results check failed on device [%d], expected %d, but got %ld at index %d, device result check: %s\n",
            mype, i, h_dest[faultIdx], faultIdx, *resultflag ? "passed" : "failed");
    }

    nvshmem_free(d_buffer);
    MUSA_CHECK(musaFreeHost(h_buffer));

    nvshmem_finalize();

#ifdef NVSHMEMTEST_MPI_SUPPORT
    if (use_mpi) MPI_Finalize();
#endif

    return 0;
}
