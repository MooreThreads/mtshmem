/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2024, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef _NVSHMEMX_COLLECTIVE_LAUNCH_APIS_H_
#define _NVSHMEMX_COLLECTIVE_LAUNCH_APIS_H_

#include <musa_runtime.h>

#if !defined __MUSACC_RTC__
int nvshmemx_collective_launch(const void *func, dim3 gridDims, dim3 blockDims, void **args,
                               size_t sharedMem, musaStream_t stream);
int nvshmemx_collective_launch_query_gridsize(const void *func, dim3 blockDims, void **args,
                                              size_t sharedMem, int *gridsize);
#endif

#endif
