/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */
/*
 * Copyright (c) 2022-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#include "internal/host/mtmlwrap.h"
#include <dlfcn.h>                                       // for dlsym, dlclose, dlopen
#include <stdio.h>                                       // for NULL, snprintf
#include <string.h>                                      // for memset
#include "non_abi/nvshmemx_error.h"                      // for NVSHMEMI_ERROR_PRINT
#include "internal/host/debug.h"                         // for INFO, NVSHMEM_INIT
#include "internal/host/util.h"                          // for nvshmemi_options
#include "bootstrap_host_transport/env_defs_internal.h"  // for nvshmemi_options_s

#define LOAD_SYM(handle, symbol, funcptr, optional, ret)        \
    do {                                                        \
        void **cast = (void **)&funcptr;                        \
        void *tmp = dlsym(handle, symbol);                      \
        *cast = tmp;                                            \
        if (*cast == NULL && !optional) {                       \
            NVSHMEMI_ERROR_PRINT("Retrieve %s failed", symbol); \
            ret = NVSHMEMX_ERROR_INTERNAL;                      \
        }                                                       \
    } while (0)

int nvshmemi_nvml_ftable_init(struct nvml_function_table *mtml_ftable, void **mtml_handle) {
    int status = NVSHMEMX_SUCCESS;
    char path[1024];

    if (!nvshmemi_options.MTML_PATH_provided)
        snprintf(path, 1024, "%s", "libmtml.so");
    else
        snprintf(path, 1024, "%s/%s", nvshmemi_options.MTML_PATH, "libmtml.so");

    *mtml_handle = dlopen(path, RTLD_NOW);
    if (!(*mtml_handle)) {
        INFO(NVSHMEM_INIT, "MTML library not found. %s", path);
        status = NVSHMEMX_ERROR_NOT_SUPPORTED;
    } else {
        INFO(NVSHMEM_INIT, "MTML library found. %s", path);
        LOAD_SYM(*mtml_handle, "mtmlLibraryInit", mtml_ftable->mtmlLibraryInit, 0, status);
        LOAD_SYM(*mtml_handle, "mtmlLibraryShutDown", mtml_ftable->mtmlLibraryShutDown, 0, status);
        LOAD_SYM(*mtml_handle, "mtmlLibraryInitDeviceByPciSbdf",
                 mtml_ftable->mtmlLibraryInitDeviceByPciSbdf, 0, status);
        LOAD_SYM(*mtml_handle, "mtmlDeviceGetP2PStatus", mtml_ftable->mtmlDeviceGetP2PStatus, 0,
                 status);
        LOAD_SYM(*mtml_handle, "mtmlDeviceCountMtLinkLayouts",
                 mtml_ftable->mtmlDeviceCountMtLinkLayouts, 0, status);
        LOAD_SYM(*mtml_handle, "mtmlDeviceGetGpuFabricInfoV",
                 mtml_ftable->mtmlDeviceGetGpuFabricInfoV, 1, status);
        LOAD_SYM(*mtml_handle, "mtmlLogGetConfiguration",
                 mtml_ftable->mtmlLogGetConfiguration, 0, status);
        LOAD_SYM(*mtml_handle, "mtmlLogSetConfiguration",
                 mtml_ftable->mtmlLogSetConfiguration, 0, status);
    }

    if (nvshmemi_options.DEBUG_MTML_provided) {
        mtmlLogConfiguration_t config{};

        mtmlReturn_t mtml_status = mtml_ftable->mtmlLogGetConfiguration(&config);
        if (mtml_status == MTML_SUCCESS) {
            char file[] = "mtml.log";

            const static struct {
                const char *name;
                MtmlLogLevel level;
            } level_map[] = { 
                {"FATAL", MTML_LOG_LEVEL_FATAL},
                {"ERROR", MTML_LOG_LEVEL_ERROR},
                {"WARN", MTML_LOG_LEVEL_WARNING},
                {"INFO", MTML_LOG_LEVEL_INFO},
            };

            for (const auto &[name, level] : level_map) {
                if (strcmp(nvshmemi_options.DEBUG_MTML, name) == 0) {
                    config.fileConfig.level = level;
                    break;
                }
            }

            if (config.fileConfig.level == MTML_LOG_LEVEL_OFF) {
                NVSHMEMI_ERROR_PRINT("Invalid mtml debug level: %s.", nvshmemi_options.DEBUG_MTML);
                status = NVSHMEMX_ERROR_INTERNAL;
            }

            if (status == NVSHMEMX_SUCCESS) {
                config.fileConfig.size = MTML_CONFIG_MAGIC_NUM;
                memset(config.fileConfig.file, 0, MTML_LOG_FILE_PATH_BUFFER_SIZE);
                memcpy(config.fileConfig.file, file, strlen(file));
                config.callbackConfig.callback = nullptr;
                config.callbackConfig.level = MTML_LOG_LEVEL_OFF;

                mtml_status = mtml_ftable->mtmlLogSetConfiguration(&config);
                if (mtml_status != MTML_SUCCESS) {
                    NVSHMEMI_ERROR_PRINT("Failed to set MTML log configuration.");
                    status = NVSHMEMX_ERROR_INTERNAL;
                }
            }
        } else {
            NVSHMEMI_ERROR_PRINT("Failed to get MTML log configuration.");
            status = NVSHMEMX_ERROR_INTERNAL;
        }
    }

    if (status != NVSHMEMX_SUCCESS) {
        nvshmemi_nvml_ftable_fini(mtml_ftable, mtml_handle);
    }
    return status;
}

void nvshmemi_nvml_ftable_fini(struct nvml_function_table *mtml_ftable, void **mtml_handle) {
    if (*mtml_handle) {
        dlclose(*mtml_handle);
        *mtml_handle = NULL;
        memset(mtml_ftable, 0, sizeof(*mtml_ftable));
    }
}
