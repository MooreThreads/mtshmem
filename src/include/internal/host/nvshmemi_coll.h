/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2020, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef NVSHMEMI_COLL_H
#define NVSHMEMI_COLL_H

#include "host/nvshmem_macros.h"
#include "internal/host/cuda_runtime_compatible.h"

#define DECL_NVSHMEMI_TYPENAME_OP_REDUCE(TYPENAME, TYPE, OP)             \
    NVSHMEMI_HOST_PREFIX void nvshmemi_##TYPENAME##_##OP##_reduce( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nreduce); \
    NVSHMEMI_DEVICE_PREFIX void nvshmemi_##TYPENAME##_##OP##_reduce( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nreduce);

NVSHMEMI_REPT_FOR_BITWISE_REDUCE_TYPES(DECL_NVSHMEMI_TYPENAME_OP_REDUCE, and)
NVSHMEMI_REPT_FOR_BITWISE_REDUCE_TYPES(DECL_NVSHMEMI_TYPENAME_OP_REDUCE, or)
NVSHMEMI_REPT_FOR_BITWISE_REDUCE_TYPES(DECL_NVSHMEMI_TYPENAME_OP_REDUCE, xor)

NVSHMEMI_REPT_FOR_STANDARD_REDUCE_TYPES(DECL_NVSHMEMI_TYPENAME_OP_REDUCE, max)
NVSHMEMI_REPT_FOR_STANDARD_REDUCE_TYPES(DECL_NVSHMEMI_TYPENAME_OP_REDUCE, min)

NVSHMEMI_REPT_FOR_ARITH_REDUCE_TYPES(DECL_NVSHMEMI_TYPENAME_OP_REDUCE, sum)
NVSHMEMI_REPT_FOR_ARITH_REDUCE_TYPES(DECL_NVSHMEMI_TYPENAME_OP_REDUCE, prod)
#undef DECL_NVSHMEMI_TYPENAME_OP_REDUCE

#define DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP(SC, TYPENAME, TYPE, OP)            \
    __device__ void nvshmemxi_##TYPENAME##_##OP##_reduce_##SC(                           \
        TYPE *dest, const TYPE *source, size_t nreduce, int start, int stride, int size, \
        uint64_t *pWrk, uint64_t *pSync);

#define DECL_NVSHMEMI_REDUCE_THREADGROUP(SC)                                                       \
    NVSHMEMI_REPT_FOR_BITWISE_REDUCE_TYPES_WITH_SCOPE(                                             \
        DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP, SC, and)                                    \
    NVSHMEMI_REPT_FOR_BITWISE_REDUCE_TYPES_WITH_SCOPE(                                             \
        DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP, SC, or)                                     \
    NVSHMEMI_REPT_FOR_BITWISE_REDUCE_TYPES_WITH_SCOPE(                                             \
        DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP, SC, xor)                                    \
                                                                                                   \
    NVSHMEMI_REPT_FOR_STANDARD_REDUCE_TYPES_WITH_SCOPE(                                            \
        DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP, SC, max)                                    \
    NVSHMEMI_REPT_FOR_STANDARD_REDUCE_TYPES_WITH_SCOPE(                                            \
        DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP, SC, min)                                    \
                                                                                                   \
    NVSHMEMI_REPT_FOR_ARITH_REDUCE_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP, \
                                                    SC, sum)                                       \
    NVSHMEMI_REPT_FOR_ARITH_REDUCE_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP, \
                                                    SC, prod)

DECL_NVSHMEMI_REDUCE_THREADGROUP(warp)
DECL_NVSHMEMI_REDUCE_THREADGROUP(block)
#undef DECL_NVSHMEMXI_TYPENAME_OP_REDUCE_THREADGROUP
#undef DECL_NVSHMEMI_REDUCE_THREADGROUP

#define DECL_NVSHMEMXI_TYPENAME_BROADCAST_THREADGROUP(SC, TYPENAME, TYPE)  \
    NVSHMEMI_HOST_PREFIX void nvshmemxi_##TYPENAME##_broadcast_##SC( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nelems, int PE_root); \
    NVSHMEMI_DEVICE_PREFIX void nvshmemxi_##TYPENAME##_broadcast_##SC( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nelems, int PE_root);

NVSHMEMI_REPT_FOR_STANDARD_RMA_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_BROADCAST_THREADGROUP, warp)
NVSHMEMI_REPT_FOR_STANDARD_RMA_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_BROADCAST_THREADGROUP,
                                                block)
#undef DECL_NVSHMEMXI_TYPENAME_BROADCAST_THREADGROUP

#define DECL_NVSHMEMXI_TYPENAME_FCOLLECT_THREADGROUP(SC, TYPENAME, TYPE)  \
    NVSHMEMI_HOST_PREFIX void nvshmemxi_##TYPENAME##_fcollect_##SC( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nelems); \
    NVSHMEMI_DEVICE_PREFIX void nvshmemxi_##TYPENAME##_fcollect_##SC( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nelems);

NVSHMEMI_REPT_FOR_STANDARD_RMA_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_FCOLLECT_THREADGROUP, warp)
NVSHMEMI_REPT_FOR_STANDARD_RMA_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_FCOLLECT_THREADGROUP, block)
#undef DECL_NVSHMEMXI_TYPENAME_FCOLLECT_THREADGROUP

#define DECL_NVSHMEMXI_TYPENAME_ALLTOALL_THREADGROUP(SC, TYPENAME, TYPE)  \
    NVSHMEMI_HOST_PREFIX void nvshmemxi_##TYPENAME##_alltoall_##SC( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nelems); \
    NVSHMEMI_DEVICE_PREFIX void nvshmemxi_##TYPENAME##_alltoall_##SC( \
        nvshmem_team_t team, TYPE *dest, const TYPE *source, size_t nelems);

NVSHMEMI_REPT_FOR_STANDARD_RMA_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_ALLTOALL_THREADGROUP, warp)
NVSHMEMI_REPT_FOR_STANDARD_RMA_TYPES_WITH_SCOPE(DECL_NVSHMEMXI_TYPENAME_ALLTOALL_THREADGROUP, block)
#undef DECL_NVSHMEMXI_TYPENAME_ALLTOALL_THREADGROUP

NVSHMEMI_HOST_PREFIX void nvshmemi_barrier(nvshmem_team_t team);
NVSHMEMI_DEVICE_PREFIX void nvshmemi_barrier(nvshmem_team_t team);

#ifdef __CUDA_ARCH__
__device__ void nvshmemxi_barrier_warp(nvshmem_team_t team);
__device__ void nvshmemxi_barrier_block(nvshmem_team_t team);
__device__ void nvshmemi_sync(nvshmem_team_t team);
__device__ void nvshmemxi_sync_warp(nvshmem_team_t team);
__device__ void nvshmemxi_sync_block(nvshmem_team_t team);
#endif

#endif /* NVSHMEMI_COLL_H */
