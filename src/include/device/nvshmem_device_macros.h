/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef _NVSHMEM_DEVICE_MACROS_H_
#define _NVSHMEM_DEVICE_MACROS_H_

#include "non_abi/nvshmem_build_options.h"  // IWYU pragma: keep

/*
 * These macros represent various inlining requirements based on configuration rules.
 * All functions are force inlined in the bitcode library.
 * Macro Key:
 * NVSHMEMI_DEVICE_INLINE - inlined based on NVSHMEM_ENABLE_ALL_DEVICE_INLINING
 * NVSHMEMI_DEVICE_ALWAYS_INLINE - inlined regardless of NVSHMEM_ENABLE_ALL_DEVICE_INLINING
 * NVSHMEMI_DEVICE_ALWAYS_FORCE_INLINE - like above, but uses NVSHMEMI_DEVICE_ALWAYS_FORCE_INLINE
 */

#if !defined __clang__
#define NVSHMEMI_DEVICE_ALWAYS_INLINE inline
#define NVSHMEMI_DEVICE_ALWAYS_FORCE_INLINE __forceinline__
#define NVSHMEM_ALWAYS_STATIC static
#if defined NVSHMEM_ENABLE_ALL_DEVICE_INLINING
#define NVSHMEMI_STATIC static
#define NVSHMEMI_DEVICE_INLINE inline
#else
#define NVSHMEMI_DEVICE_INLINE __noinline__
#define NVSHMEMI_STATIC static
#endif
#else
/* Bitcode-only build (init_device.cu) mangles names of functions marked NVSHMEMI_STATIC;
 * normal Clang/MUSA device compilation uses static on coll helpers (NVSHMEMI_STATIC). */
#if defined __clang_llvm_bitcode_lib__
#define NVSHMEMI_STATIC
#else
#define NVSHMEMI_STATIC static
#endif
#if defined NVSHMEM_ENABLE_ALL_DEVICE_INLINING
#define NVSHMEMI_DEVICE_INLINE __attribute__((always_inline))
#else
#define NVSHMEMI_DEVICE_INLINE __noinline__
#endif
#if (defined(__MUSACC__) || defined(__MUSACC_RDC__)) && !defined(__clang_llvm_bitcode_lib__)
/* Public device API in nvshmem_defines.h is declared in nvshmem_api.h without "static"; use C++
 * inline + always_inline so MCC matches those declarations and ODR/comdat can merge TU copies.
 * Plain attribute-only always_inline still emitted out-of-line copies in some MCC+lld fatbin
 * links; "static" breaks the earlier non-static declarations from nvshmem.h. */
#define NVSHMEMI_DEVICE_ALWAYS_INLINE inline __attribute__((always_inline))
#define NVSHMEMI_DEVICE_ALWAYS_FORCE_INLINE inline __attribute__((always_inline))
#else
#define NVSHMEMI_DEVICE_ALWAYS_INLINE __attribute__((always_inline))
#define NVSHMEMI_DEVICE_ALWAYS_FORCE_INLINE __attribute__((always_inline))
#endif
#endif

#endif
