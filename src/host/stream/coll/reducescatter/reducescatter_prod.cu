/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2020, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#include "reducescatter_common.cuh"
#include "internal/host/cuda_runtime_compatible.h"
#include "internal/non_abi/nvshmemi_h_to_d_coll_defs.cuh"

REPT_FOR_BITWISE_TYPES(INSTANTIATE_NVSHMEMI_CALL_REDUCESCATTER_ON_STREAM_KERNEL, PROD)
REPT_FOR_FLOATING_TYPES(INSTANTIATE_NVSHMEMI_CALL_REDUCESCATTER_ON_STREAM_KERNEL, PROD)
