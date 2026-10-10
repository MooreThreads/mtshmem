/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2017-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef NVSHMEM_ERROR_CODES_INTERNAL_H_
#define NVSHMEM_ERROR_CODES_INTERNAL_H_

typedef enum {
    NVSHMEMI_SUCCESS = 0,
    NVSHMEMI_UNHANDLED_CUDA_ERROR = 1,
    NVSHMEMI_SYSTEM_ERROR = 2,
    NVSHMEMI_INTERNAL_ERROR = 3,
    NVSHMEMI_INVALID_ARGUMENT = 4,
    NVSHMEMI_INVALID_USAGE = 5,
    NVSHMEMI_ERROR_SKIPPED = 6,
    NVSHMEMI_NUM_RESULTS = 7
} nvshmemResult_t;

#endif
