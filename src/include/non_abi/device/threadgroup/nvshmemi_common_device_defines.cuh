/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2016-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef _NVSHMEM_COMMON_DEVICE_DEFINES_CUH_
#define _NVSHMEM_COMMON_DEVICE_DEFINES_CUH_
#include "internal/host/cuda_runtime_compatible.h"
#include "device_host/nvshmem_common.cuh"

#if defined(__CUDACC__) || defined(__CUDACC_RDC__)
#define EXTERN_CONSTANT extern __constant__
#elif defined(__clang__)
#define EXTERN_CONSTANT extern __constant__ __attribute__((address_space(4)))
#else
#define EXTERN_CONSTANT static __constant__
#endif
EXTERN_CONSTANT nvshmemi_device_host_state_t nvshmemi_device_state_d;
#undef EXTERN_CONSTANT

typedef enum {
    nvshmemi_threadgroup_thread = 0,
    NVSHMEMI_THREADGROUP_THREAD = 0,
    nvshmemi_threadgroup_warp = 1,
    NVSHMEMI_THREADGROUP_WARP = 1,
    nvshmemi_threadgroup_warpgroup = 2,
    NVSHMEMI_THREADGROUP_WARPGROUP = 2,
    nvshmemi_threadgroup_block = 3,
    NVSHMEMI_THREADGROUP_BLOCK = 3
} threadgroup_t;

#ifdef __CUDA_ARCH__

template <threadgroup_t scope>
__device__ __forceinline__ int nvshmemi_thread_id_in_threadgroup() {
    switch (scope) {
        case NVSHMEMI_THREADGROUP_THREAD:
            return 0;
        case NVSHMEMI_THREADGROUP_WARP:
#if defined(__CUDA_ARCH__) && __CUDA_ARCH__ == 310
            return __musa_get_special_register(LANE_ID); // replaced ("mov.u32  %0, %laneid;" : "=r"(myIdx));
#else
            return threadIdx.x % NVSHMEMI_WARP_SIZE;
#endif
        case NVSHMEMI_THREADGROUP_WARPGROUP:
            return (
                (threadIdx.x + threadIdx.y * blockDim.x + threadIdx.z * blockDim.x * blockDim.y) %
                (4 * warpSize));
        case NVSHMEMI_THREADGROUP_BLOCK:
            return (threadIdx.x + threadIdx.y * blockDim.x + threadIdx.z * blockDim.x * blockDim.y);
        default:
            // printf("unrecognized threadscope passed\n");
            assert(0);
            return -1;
    }
}

template <threadgroup_t scope>
__device__ inline int nvshmemi_threadgroup_size() {
    switch (scope) {
        case NVSHMEMI_THREADGROUP_THREAD:
            return 1;
        case NVSHMEMI_THREADGROUP_WARP:
            return ((blockDim.x * blockDim.y * blockDim.z) < warpSize)
                       ? (blockDim.x * blockDim.y * blockDim.z)
                       : warpSize;
        case NVSHMEMI_THREADGROUP_WARPGROUP:
            return ((blockDim.x * blockDim.y * blockDim.z) < (4 * warpSize))
                       ? (blockDim.x * blockDim.y * blockDim.z)
                       : (4 * warpSize);
        case NVSHMEMI_THREADGROUP_BLOCK:
            return (blockDim.x * blockDim.y * blockDim.z);
        default:
            // printf("unrecognized threadscope passed\n");
            assert(0);
            return -1;
    }
}

template <threadgroup_t scope>
__device__ inline void nvshmemi_threadgroup_sync() {
    uint32_t tid, barrierId;
    switch (scope) {
        case NVSHMEMI_THREADGROUP_THREAD:
            return;
        case NVSHMEMI_THREADGROUP_WARP:
            __syncwarp();
            break;
        case NVSHMEMI_THREADGROUP_WARPGROUP:
            tid =
                threadIdx.x + (threadIdx.y * blockDim.x) + (threadIdx.z * blockDim.x * blockDim.y);
            barrierId = (tid / (4 * warpSize));
            assert((blockDim.x * blockDim.y * blockDim.z) % (4 * warpSize) == 0);
            assert((barrierId < 16) && "Reduce blocksize");
            asm volatile("bar.sync %0, %1;" : : "r"(barrierId), "r"(4 * warpSize));
            break;
        case NVSHMEMI_THREADGROUP_BLOCK:
            __syncthreads();
            break;
        default:
            // printf("unrecognized threadscope passed\n");
            assert(0);
            break;
    }
}
#endif /* __CUDA_ARCH__ */

#endif
