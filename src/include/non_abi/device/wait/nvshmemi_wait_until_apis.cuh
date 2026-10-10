/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2016-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef _NVSHMEM_WAIT_UNTIL_APIS_CUH_
#define _NVSHMEM_WAIT_UNTIL_APIS_CUH_

#ifdef __MUSA_ARCH__

#include <musa_runtime.h>
#include "device_host_transport/nvshmem_constants.h"
#include "device/nvshmem_device_macros.h"
#include "non_abi/device/threadgroup/nvshmemi_common_device_defines.cuh"
#include "device_host/nvshmem_common.cuh"
#include "non_abi/nvshmem_build_options.h"

#define TIMEOUT_NCYCLES 4e10

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_check_timeout_and_log(
    long long int start, int caller, int line, uintptr_t signal_addr, T signal_val_found,
    T signal_val_expected) {
    long long int now;
    now = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(now));
    nvshmemi_timeout_t *timeout_d = nvshmemi_device_state_d.timeout;
    timeout_d->caller = caller;
    timeout_d->line = (uint64_t)line;
    timeout_d->signal_addr = signal_addr;
    *(T *)(&timeout_d->signal_val_found) = signal_val_found;
    *(T *)(&timeout_d->signal_val_expected) = signal_val_expected;
    if ((now - start) > TIMEOUT_NCYCLES) {
        *((volatile uint64_t *)(&timeout_d->signal)) = NVSHMEMI_TIMEOUT_ACTIVE;
    } else {
        *((volatile uint64_t *)(&timeout_d->signal)) = NVSHMEMI_TIMEOUT_POLLING;
    }
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_check_done_and_log(
    int caller, int line, uintptr_t signal_addr, T signal_val_found, T signal_val_expected) {
    nvshmemi_timeout_t *timeout_d = nvshmemi_device_state_d.timeout;
    timeout_d->caller = caller;
    timeout_d->line = (uint64_t)line;
    timeout_d->signal_addr = signal_addr;
    *(T *)(&timeout_d->signal_val_found) = signal_val_found;
    *(T *)(&timeout_d->signal_val_expected) = signal_val_expected;
    *((volatile uint64_t *)(&timeout_d->signal)) = NVSHMEMI_TIMEOUT_DONE;
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until_greater_than(volatile T *addr,
                                                                               T val, int caller,
                                                                               int line) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    long long int start = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(start));
#endif
    while (*addr <= val) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
        nvshmemi_check_timeout_and_log<T>(start, caller, line, (uintptr_t)addr, *addr, val);
#endif
    }
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    nvshmemi_check_done_and_log<T>(caller, line, (uintptr_t)addr, *addr, val);
#endif
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until_greater_than_equals(
    volatile T *addr, T val, int caller, int line) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    long long int start = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(start));
#endif
    while (*addr < val) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
        nvshmemi_check_timeout_and_log<T>(start, caller, line, (uintptr_t)addr, *addr, val);
#endif
    }
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    nvshmemi_check_done_and_log<T>(caller, line, (uintptr_t)addr, *addr, val);
#endif
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until_lesser_than(volatile T *addr,
                                                                              T val, int caller,
                                                                              int line) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    long long int start = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(start));
#endif
    while (*addr >= val) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
        nvshmemi_check_timeout_and_log<T>(start, caller, line, (uintptr_t)addr, *addr, val);
#endif
    }
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    nvshmemi_check_done_and_log<T>(caller, line, (uintptr_t)addr, *addr, val);
#endif
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until_lesser_than_equals(
    volatile T *addr, T val, int caller, int line) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    long long int start = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(start));
#endif
    while (*addr > val) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
        nvshmemi_check_timeout_and_log<T>(start, caller, line, (uintptr_t)addr, *addr, val);
#endif
    }
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    nvshmemi_check_done_and_log<T>(caller, line, (uintptr_t)addr, *addr, val);
#endif
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until_equals(volatile T *addr, T val,
                                                                         int caller, int line) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    long long int start = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(start));
#endif
    while (*addr != val) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
        nvshmemi_check_timeout_and_log<T>(start, caller, line, (uintptr_t)addr, *addr, val);
#endif
    }
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    nvshmemi_check_done_and_log<T>(caller, line, (uintptr_t)addr, *addr, val);
#endif
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until_not_equals(volatile T *addr,
                                                                             T val, int caller,
                                                                             int line) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    long long int start = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(start));
#endif
    while (*addr == val) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
        nvshmemi_check_timeout_and_log<T>(start, caller, line, (uintptr_t)addr, *addr, val);
#endif
    }
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    nvshmemi_check_done_and_log<T>(caller, line, (uintptr_t)addr, *addr, val);
#endif
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until_greater_than_equals_add(
    volatile T *addr, uint64_t toadd, T val, int caller, int line) {
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    long long int start = clock64(); // replace asm volatile("mov.u64  %0, %globaltimer;" : "=l"(start));
#endif
    T valataddr;
    do {
        valataddr = *addr;
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
        nvshmemi_check_timeout_and_log<T>(start, caller, line, (uintptr_t)addr, valataddr + toadd, val);
#endif
    } while (valataddr + toadd < val);
#ifdef NVSHMEM_TIMEOUT_DEVICE_POLLING
    nvshmemi_check_done_and_log<T>(caller, line, (uintptr_t)addr, valataddr + toadd, val);
#endif
}

template <typename T>
__device__ NVSHMEMI_DEVICE_ALWAYS_INLINE void nvshmemi_wait_until(volatile T *ivar, int cmp,
                                                                  T cmp_value) {
    if (NVSHMEM_CMP_GE == cmp) {
        nvshmemi_wait_until_greater_than_equals<T>(ivar, cmp_value,
                                                   NVSHMEMI_CALL_SITE_WAIT_UNTIL_GE, __LINE__);
    } else if (NVSHMEM_CMP_EQ == cmp) {
        nvshmemi_wait_until_equals<T>(ivar, cmp_value, NVSHMEMI_CALL_SITE_WAIT_UNTIL_EQ, __LINE__);
    } else if (NVSHMEM_CMP_NE == cmp) {
        nvshmemi_wait_until_not_equals<T>(ivar, cmp_value, NVSHMEMI_CALL_SITE_WAIT_UNTIL_NE, __LINE__);
    } else if (NVSHMEM_CMP_GT == cmp) {
        nvshmemi_wait_until_greater_than<T>(ivar, cmp_value, NVSHMEMI_CALL_SITE_WAIT_UNTIL_GT, __LINE__);
    } else if (NVSHMEM_CMP_LT == cmp) {
        nvshmemi_wait_until_lesser_than<T>(ivar, cmp_value, NVSHMEMI_CALL_SITE_WAIT_UNTIL_LT, __LINE__);
    } else if (NVSHMEM_CMP_LE == cmp) {
        nvshmemi_wait_until_lesser_than_equals<T>(ivar, cmp_value,
                                                  NVSHMEMI_CALL_SITE_WAIT_UNTIL_LE, __LINE__);
    }
}

#endif /* __MUSA_ARCH__ */
#endif
