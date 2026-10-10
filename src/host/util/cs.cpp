/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
 *
 * See COPYRIGHT for license information
 */

#include <pthread.h>
#include <stddef.h>

#include "non_abi/nvshmemx_error.h"

static pthread_mutex_t global_mutex;

void nvshmemu_thread_cs_init() {
    int status = pthread_mutex_init(&global_mutex, NULL);
    NVSHMEMI_NZ_SYSCHECK_EXIT(status, "mutex init failed \n");
}

void nvshmemu_thread_cs_finalize() {
    int status = pthread_mutex_destroy(&global_mutex);
    NVSHMEMI_NZ_SYSCHECK_EXIT(status, "mutex destroy failed \n");
}

void nvshmemu_thread_cs_enter() {
    int status = pthread_mutex_lock(&global_mutex);
    NVSHMEMI_NZ_SYSCHECK_EXIT(status, "mutex lock failed \n");
}

void nvshmemu_thread_cs_exit() {
    int status = pthread_mutex_unlock(&global_mutex);
    NVSHMEMI_NZ_SYSCHECK_EXIT(status, "mutex unlock failed \n");
}
