/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2024, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef _NVSHMEM_MACROS_H_
#define _NVSHMEM_MACROS_H_

#include <musa_runtime.h>

// #ifdef __MUSA_ARCH__
// #ifdef NVSHMEMI_HOST_ONLY
// #define NVSHMEMI_HOSTDEVICE_PREFIX __host__
// #else
// #ifdef NVSHMEMI_DEVICE_ONLY
// #define NVSHMEMI_HOSTDEVICE_PREFIX __device__
// #else
// #define NVSHMEMI_HOSTDEVICE_PREFIX __host__ __device__
// #endif
// #endif
// #else
// #define NVSHMEMI_HOSTDEVICE_PREFIX
// #endif

/* impossible to use NVSHMEMI_DEVICE_ONLY 
 * use only when declaring both host and device funtions
 */
#ifdef __MUSACC__
#ifdef NVSHMEMI_HOST_ONLY
#define NVSHMEMI_DEVICE_PREFIX
#define NVSHMEMI_STATIC_DEVICE_PREFIX
#define NVSHMEMI_HOST_PREFIX __host__
#define NVSHMEMI_STATIC_HOST_PREFIX static __host__
#else
#define NVSHMEMI_DEVICE_PREFIX __device__
#define NVSHMEMI_STATIC_DEVICE_PREFIX static __device__
#define NVSHMEMI_HOST_PREFIX __host__
#define NVSHMEMI_STATIC_HOST_PREFIX static __host__
#endif
#else
#define NVSHMEMI_DEVICE_PREFIX
#define NVSHMEMI_STATIC_DEVICE_PREFIX
#define NVSHMEMI_HOST_PREFIX
#define NVSHMEMI_STATIC_HOST_PREFIX static
#endif

#ifndef NVSHMEMI_HOSTDEVICE_PREFIX
#ifdef __MUSACC__
#define NVSHMEMI_HOSTDEVICE_PREFIX __host__ __device__
#else
#define NVSHMEMI_HOSTDEVICE_PREFIX
#endif
#endif

#endif