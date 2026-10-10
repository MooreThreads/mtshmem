/*
 * Copyright (c) 2022-2023, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef NVSHMEM_NCCL_COMPATIBLE_H
#define NVSHMEM_NCCL_COMPATIBLE_H

#include "mccl.h"

/* NCCL -> MCCL mapping for API compatibility (coll code uses NCCL names) */

/* Data types */
#define ncclDataType_t  mcclDataType_t
#define ncclResult_t    mcclResult_t
#define ncclRedOp_t     mcclRedOp_t
#define ncclComm_t      mcclComm_t
#define ncclUniqueId    mcclUniqueId
#define ncclSuccess     mcclSuccess

/* Reduction ops */
#define ncclSum     mcclSum
#define ncclProd    mcclProd
#define ncclMin     mcclMin
#define ncclMax     mcclMax
#define ncclNumOps  mcclNumOps

/* Data type constants */
#define ncclChar    mcclChar
#define ncclUint8   mcclUint8
#define ncclInt     mcclInt
#define ncclInt64   mcclInt64
#define ncclUint32  mcclUint32
#define ncclUint64  mcclUint64
#define ncclHalf    mcclHalf
#define ncclFloat   mcclFloat
#define ncclDouble  mcclDouble
#define ncclBfloat16 mcclBfloat16
#define ncclNumTypes mcclNumTypes

/* Version macro (for NCCL_VERSION_CODE used in coll) */
#ifndef NCCL_VERSION_CODE
#define NCCL_VERSION_CODE MCCL_VERSION_CODE
#endif

#endif /* NVSHMEM_NCCL_COMPATIBLE_H */
