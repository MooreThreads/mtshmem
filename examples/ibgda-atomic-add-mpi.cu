/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * support two types of APIs: standard NVSHMEM and deepEP IBGDA
 * three test cases for nvshmem_int_atomic_add functionality
 * 1. Each PE adds 5 to its own counter (local test)
 * 2. Each PE adds (mype + 1) to the next PE's counter (remote test)
 * 3. Each PE adds (mype + 1) to all other PEs' counters with warp specialization (each lane in a warp targets a different PE)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <cstdint>
#include "mpi.h"
#include "nvshmem.h"
#include "nvshmemx.h"
// Include from deepEP for IBGDA atomic operations
// #include "include/ibgda_device_deepEP.cuh"

#define USE_DEEPEP_API 0

// MUSA compatibility
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

#define MPI_CHECK(stmt)                                                          \
    do {                                                                         \
        int result = (stmt);                                                     \
        if (MPI_SUCCESS != result) {                                             \
            fprintf(stderr, "[%s:%d] MPI failed with error %d \n", __FILE__, __LINE__, result); \
            exit(-1);                                                            \
        }                                                                        \
    } while (0)

static void set_env_default(const char *name, const char *value) {
    if (getenv(name) == nullptr) setenv(name, value, 0);
}

// Simple test kernel for atomic add operations 
__global__ void test_atomic_add_simple(int* counter, int val, int target_pe, bool is_local = true) {
#if  USE_DEEPEP_API
    deep_ep::nvshmemi_ibgda_amo_nonfetch_add(counter, val, target_pe, 0, is_local);  // Using deepEP version
#else
    if (is_local) {
        atomicAdd(counter, val);
    } else {
        nvshmem_int_atomic_add(counter, val, target_pe);
    }
#endif
}

// Complex test kernel for atomic add operations
__global__ void test_atomic_add(int* counter, int mype, int npes) {
    int lane_id = threadIdx.x % 32;
    int warp_id = threadIdx.x / 32;
    
    if (threadIdx.x == 0) {
        printf("[GPU %d] Starting complex atomic add test\n", mype);
    }
    
    __syncthreads();
    
    // Test: Each PE adds (mype + 1) to all other PEs' counters by each lane in a warp
    if (warp_id == 0 && lane_id < npes) {
        int target_pe = lane_id;
        if (target_pe != mype) {
            int increment_value = mype + 1;
            
            printf("[GPU %d] Lane %d: Adding %d to counter on PE %d\n",
                   mype, lane_id, increment_value, target_pe);
#if USE_DEEPEP_API
            deep_ep::nvshmemi_ibgda_amo_nonfetch_add(counter, increment_value, target_pe, 0, false);  // Using deepEP version
#else
            // Use standard NVSHMEM atomic add operation            
            nvshmem_int_atomic_add(counter, increment_value, target_pe);
#endif
        }
        __syncwarp();
    }
    
    __syncthreads();
    
    if (threadIdx.x == 0) {
        printf("[GPU %d] Complex atomic add operations completed\n", mype);
    }
}

// Verification kernel
__global__ void verify_atomic_results(int* counter, int mype, int npes) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    
    if (tid == 0) {
        printf("[GPU %d] Verifying atomic add results:\n", mype);
        
        // Check counter value
        int counter_value = *counter;
        printf("[GPU %d] Final counter value: %d\n", mype, counter_value);
        
        // Calculate expected counter value
        // Should be sum of (sender_pe + 1) for all PEs except myself
        int expected_counter = 0;
        for (int pe = 0; pe < npes; pe++) {
            if (pe != mype) {
                expected_counter += (pe + 1);
            }
        }
        
        printf("[GPU %d] Expected counter value: %d\n", mype, expected_counter);
        
        // Verification
        if (counter_value == expected_counter) {
            printf("[GPU %d] Atomic add verification PASSED\n", mype);
        } else {
            printf("[GPU %d] Atomic add verification FAILED: expected %d, got %d\n",
                   mype, expected_counter, counter_value);
        }
    }
}

int main(int argc, char **argv) {
    // Preserve caller-provided values so the same binary can cover the IBGDA configuration matrix.
    set_env_default("NVSHMEM_DISABLE_P2P", "1");
    set_env_default("NVSHMEM_IB_ENABLE_IBGDA", "1");
    set_env_default("NVSHMEM_IBGDA_FORCE_NIC_BUF_MEMTYPE", "hostmem");
    set_env_default("NVSHMEM_IBGDA_NIC_HANDLER", "cpu");
    // setenv("NVSHMEM_DEBUG", "1", 1); // Enable debug logging

    /* MPI Initialization -------------------------------------------- */
    MPI_CHECK(MPI_Init(&argc, &argv));
    int rank, nranks;
    MPI_CHECK(MPI_Comm_rank(MPI_COMM_WORLD, &rank));
    MPI_CHECK(MPI_Comm_size(MPI_COMM_WORLD, &nranks));

    /* NVSHMEM Initialization ------------------------------------- */
    nvshmemx_init_attr_t attr = NVSHMEMX_INIT_ATTR_INITIALIZER;
    MPI_Comm comm = MPI_COMM_WORLD;
    attr.mpi_comm = &comm;
    
    int nvshmem_result = nvshmemx_init_attr(NVSHMEMX_INIT_WITH_MPI_COMM, &attr);
    if (nvshmem_result != NVSHMEMX_SUCCESS) { 
        fprintf(stderr, "NVSHMEM initialization failed with code %d\n", nvshmem_result);
        exit(EXIT_FAILURE);
    }
    int mype = nvshmem_my_pe();
    int npes = nvshmem_n_pes();
    int local_failures = 0;

    printf("[PE %d] NVSHMEM initialized with %d PEs\n", mype, npes);
    int node_pe = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);

    printf("[Host] PE %d of %d, node PE %d\n", mype, npes, node_pe);

    /* Select GPU ------------------------------------------------- */
    MUSA_CHECK(musaSetDevice(node_pe));

    /* Symmetric Memory ------------------------------------------- */
    int* counter = (int*)nvshmem_malloc(sizeof(int));
    
    if (!counter) {
        fprintf(stderr, "PE %d: Failed to allocate symmetric memory\n", mype);
        nvshmem_finalize();
        MPI_CHECK(MPI_Finalize());
        return 1;
    }
    // Initialize counter to 0
    int counter_host = 0;
    MUSA_CHECK(musaMemcpy(counter, &counter_host, sizeof(int), musaMemcpyHostToDevice));

    if (mype == 0) {
        printf("--------test1: Each PE will add 5 to its own counter--------\n");
    }
    
    // Each PE adds 5 to its own counter (local test)
    test_atomic_add_simple<<<1,1>>>(counter, 5, mype, true);
    MUSA_CHECK(musaDeviceSynchronize());
    
    nvshmem_barrier_all();
    // Read local test results
    MUSA_CHECK(musaMemcpy(&counter_host, counter, sizeof(int), musaMemcpyDeviceToHost));
    int local_result = counter_host;
    printf("[PE %d] Local atomic add test: %d (expect 5)\n", mype, local_result);
    if (local_result != 5) local_failures++;
    
    // Reset counter
    counter_host = 0;
    MUSA_CHECK(musaMemcpy(counter, &counter_host, sizeof(int), musaMemcpyHostToDevice));
    nvshmem_barrier_all();
    
    /* Remote Test (based on rank count) ------------------------- */
    if (mype == 0) {
        printf("--------test2: Each PE will add (mype + 1) to the next PE's counter--------\n");
    }
    
    if (npes >= 2) {
        // Each PE adds (mype + 1) to the next PE's counter
        int target_pe = (mype + 1) % npes;  // Ring arrangement: PE0->PE1, PE1->PE2, ..., PE(n-1)->PE0
        int add_value = mype + 1;
        
        printf("[PE %d] Adding %d to counter on PE %d\n", mype, add_value, target_pe);
        test_atomic_add_simple<<<1,1>>>(counter, add_value, target_pe, false);  // false means remote operation
        MUSA_CHECK(musaDeviceSynchronize());
        
        nvshmem_barrier_all();
        
        // Each PE reads its own value and verifies
        MUSA_CHECK(musaMemcpy(&counter_host, counter, sizeof(int), musaMemcpyDeviceToHost));
        int remote_result = counter_host;
        
        // Calculate expected value: value added by previous PE
        int prev_pe = (mype - 1 + npes) % npes;  // Previous PE's ID
        int expected_value = prev_pe + 1;  // Value added by previous PE is (prev_pe + 1)
        
        printf("[PE %d] Remote atomic add test: %d (expect %d from PE %d)\n",
               mype, remote_result, expected_value, prev_pe);
        
        // Verify results
        if (remote_result == expected_value) {
            printf("[PE %d] Remote test PASSED\n", mype);
        } else {
            printf("[PE %d] Remote test FAILED\n", mype);
            local_failures++;
        }
    } else {
        printf("[PE %d] Skip remote test (need at least 2 PEs, got %d)\n", mype, npes);
    }
    
    nvshmem_barrier_all();

    /* Complex Test (many-to-many atomic operations) ------------- */
    // Reset counter for complex test preparation
    counter_host = 0;
    MUSA_CHECK(musaMemcpy(counter, &counter_host, sizeof(int), musaMemcpyHostToDevice));
    
    nvshmem_barrier_all();
    
    if (mype == 0) {
        printf("--------test3: Each PE will add (mype + 1) to all other PEs' counters with warp sepcilzation--------\n");
    }
    
    /* Launch Complex Test Kernel -------------------------------- */
    test_atomic_add<<<1, 32>>>(counter, mype, npes);
    MUSA_CHECK(musaDeviceSynchronize());
    
    /* Synchronize All PEs Before Verification ------------------- */
    nvshmem_barrier_all();
    
    /* Launch Verification Kernel -------------------------------- */
    verify_atomic_results<<<1, 1>>>(counter, mype, npes);
    MUSA_CHECK(musaDeviceSynchronize());

    MUSA_CHECK(musaMemcpy(&counter_host, counter, sizeof(int), musaMemcpyDeviceToHost));
    int expected_counter = 0;
    for (int pe = 0; pe < npes; pe++) {
        if (pe != mype) expected_counter += pe + 1;
    }
    if (counter_host != expected_counter) local_failures++;
    
    printf("[PE %d] Complex atomic add test completed\n", mype);
    
    /* Cleanup ---------------------------------------------------- */
    int global_failures = 0;
    MPI_CHECK(MPI_Allreduce(&local_failures, &global_failures, 1, MPI_INT, MPI_SUM, MPI_COMM_WORLD));
    if (mype == 0) {
        printf("IBGDA atomic validation %s (%d failures)\n",
               global_failures == 0 ? "PASSED" : "FAILED", global_failures);
    }

    nvshmem_free(counter);
    nvshmem_finalize();
    MPI_CHECK(MPI_Finalize());

    return global_failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
