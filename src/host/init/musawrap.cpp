/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */
/*
 * Copyright (c) 2022, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <musa.h>  // for MUresult
#if MUSART_VERSION >= 10000
#include <musaTypedefs.h>
#else
// IWYU pragma: no_include <musaTypedefs.h>
#endif

#include <musa_runtime.h>                                // for musaDriverGetVersion
#include <dlfcn.h>                                       // for dlsym, dlopen, RTLD...
#include <driver_types.h>                                // for musaError_t
#include <stdio.h>                                       // for NULL, snprintf
#include "internal/host/debug.h"                         // for WARN, INFO, NVSHMEM...
#include "internal/host/error_codes_internal.h"          // for NVSHMEMI_SYSTEM_ERROR
#include "internal/host/util.h"                          // for nvshmemi_options
#include "internal/host_transport/musawrap.h"            // for nvshmemi_cuda_fn_table
#include "bootstrap_host_transport/env_defs_internal.h"  // for nvshmemi_options_s

static enum {
    musaUninitialized,
    musaInitializing,
    musaInitialized,
    musaError
} musaState = musaUninitialized;

static void *musaLib;
static int musaDriverVersion;

static int musaPfnFuncLoader(struct nvshmemi_cuda_fn_table *table) {
    MUresult res;

/* Load mu_sym from libmusa.so and store in table->pfn_cu_sym (NVSHMEM 3.5.19 cu* API) */
#define LOAD_SYM(table, cu_sym, mu_sym, version, sym_suffix, ignore)                              \
    do {                                                                                          \
        bool not_found = false;                                                                   \
        if (table->pfn_cuGetProcAddress) {                                                        \
            res = table->pfn_cuGetProcAddress(#mu_sym, (void **)(&table->pfn_##cu_sym), version, 0); \
            if (res != 0) not_found = true;                                                       \
        } else {                                                                                  \
            table->pfn_##cu_sym = (PFN_##cu_sym##_v##version)dlsym(musaLib, #mu_sym #sym_suffix);  \
            if (table->pfn_##cu_sym == NULL) not_found = true;                                     \
        }                                                                                         \
        if (not_found) {                                                                          \
            if (!ignore) {                                                                        \
                WARN("Retrieve %s version %d failed", #mu_sym #sym_suffix, musaDriverVersion);     \
                return NVSHMEMI_SYSTEM_ERROR;                                                      \
            }                                                                                     \
        }                                                                                         \
    } while (0)

    LOAD_SYM(table, cuCtxGetDevice, muCtxGetDevice, 2000, , 0);
    LOAD_SYM(table, cuCtxSynchronize, muCtxSynchronize, 2000, , 0);
    LOAD_SYM(table, cuDeviceGet, muDeviceGet, 2000, , 0);
    LOAD_SYM(table, cuDeviceGetAttribute, muDeviceGetAttribute, 2000, , 0);
    LOAD_SYM(table, cuPointerGetAttribute, muPointerGetAttribute, 4000, , 1);
    LOAD_SYM(table, cuPointerSetAttribute, muPointerSetAttribute, 6000, , 1);
    LOAD_SYM(table, cuModuleGetGlobal, muModuleGetGlobal, 3020, _v2, 0);
    LOAD_SYM(table, cuLibraryGetGlobal, muLibraryGetGlobal, 12000, , 1);
    LOAD_SYM(table, cuGetErrorString, muGetErrorString, 6000, , 0);
    LOAD_SYM(table, cuGetErrorName, muGetErrorName, 6000, , 0);
    LOAD_SYM(table, cuCtxSetCurrent, muCtxSetCurrent, 4000, , 0);
    LOAD_SYM(table, cuDevicePrimaryCtxRetain, muDevicePrimaryCtxRetain, 7000, , 0);
    LOAD_SYM(table, cuCtxGetCurrent, muCtxGetCurrent, 4000, , 0);
    LOAD_SYM(table, cuCtxGetFlags, muCtxGetFlags, 7000, , 0);
    LOAD_SYM(table, cuCtxSetFlags, muCtxSetFlags, 11000, , 1);
    LOAD_SYM(table, cuFlushGPUDirectRDMAWrites, muFlushGPUDirectRDMAWrites, 11030, , 1);
    LOAD_SYM(table, cuMemGetHandleForAddressRange, muMemGetHandleForAddressRange, 11030, , 1);
    LOAD_SYM(table, cuMemCreate, muMemCreate, 10020, , 1);
    LOAD_SYM(table, cuMemMap, muMemMap, 10020, , 1);
    LOAD_SYM(table, cuMemAddressReserve, muMemAddressReserve, 10020, , 1);
    LOAD_SYM(table, cuMemAddressFree, muMemAddressFree, 10020, , 1);
    LOAD_SYM(table, cuMemGetAllocationGranularity, muMemGetAllocationGranularity, 10020, , 1);
    LOAD_SYM(table, cuMemGetAllocationPropertiesFromHandle,
             muMemGetAllocationPropertiesFromHandle, 10020, , 1);
    LOAD_SYM(table, cuMemImportFromShareableHandle, muMemImportFromShareableHandle, 10020, , 1);
    LOAD_SYM(table, cuMemExportToShareableHandle, muMemExportToShareableHandle, 10020, , 1);
    LOAD_SYM(table, cuMemRelease, muMemRelease, 10020, , 1);
    LOAD_SYM(table, cuMemSetAccess, muMemSetAccess, 10020, , 1);
    LOAD_SYM(table, cuMemGetAccess, muMemGetAccess, 10020, , 1);
    LOAD_SYM(table, cuMemUnmap, muMemUnmap, 10020, , 1);
    LOAD_SYM(table, cuMemRetainAllocationHandle, muMemRetainAllocationHandle, 11000, , 1);
    LOAD_SYM(table, cuMulticastCreate, muMulticastCreate, 12010, , 1);
    LOAD_SYM(table, cuMulticastAddDevice, muMulticastAddDevice, 12010, , 1);
    LOAD_SYM(table, cuMulticastBindMem, muMulticastBindMem, 12010, , 1);
    LOAD_SYM(table, cuMulticastUnbind, muMulticastUnbind, 12010, , 1);
    LOAD_SYM(table, cuMulticastGetGranularity, muMulticastGetGranularity, 12010, , 1);
    LOAD_SYM(table, cuStreamWriteValue64, muStreamWriteValue64, 9000, _v2, 1);
    LOAD_SYM(table, cuStreamWaitValue64, muStreamWaitValue64, 9000, _v2, 1);
    return NVSHMEMI_SUCCESS;
}

int nvshmemi_cuda_library_init(struct nvshmemi_cuda_fn_table *table) {
    musaError_t musa_err;

    if (musaState == musaInitialized) return NVSHMEMI_SUCCESS;
    if (musaState == musaError) return NVSHMEMI_SYSTEM_ERROR;

    /*
     * Load MUSA driver library
     */
    char path[1024];
    if (!nvshmemi_options.MUSA_PATH_provided)
        snprintf(path, 1024, "%s", "libmusa.so");
    else
        snprintf(path, 1024, "%s/%s", nvshmemi_options.MUSA_PATH, "libmusa.so");

    musaLib = dlopen(path, RTLD_LAZY);
    if (musaLib == NULL) {
        WARN("Failed to find MUSA library in %s (NVSHMEM_MUSA_PATH=%s)", path,
             nvshmemi_options.MUSA_PATH);
        goto error;
    }

    /*
     * Load initial MUSA functions
     */

    table->pfn_cuInit = (PFN_cuInit_v2000)dlsym(musaLib, "muInit");
    if (table->pfn_cuInit == NULL) {
        WARN("Failed to load MUSA missing symbol muInit");
        goto error;
    }

    musa_err = musaDriverGetVersion(&musaDriverVersion);
    if (musa_err != 0) {
        WARN("musaDriverGetVersion failed with %d", musa_err);
        goto error;
    }
    INFO(NVSHMEM_INIT, "musaDriverVersion %d", musaDriverVersion);

    // table->pfn_cuGetProcAddress = (PFN_cuGetProcAddress_v11030)dlsym(musaLib, "muGetProcAddress");
    table->pfn_cuGetProcAddress = nullptr;

    /*
     * Required to initialize the MUSA Driver.
     * Multiple calls of muInit() will return immediately
     * without making any relevant change
     */
    table->pfn_cuInit(0);

    if (musaPfnFuncLoader(table)) {
        WARN("MUSA some PFN functions not found in the library");
        goto error;
    }

    musaState = musaInitialized;
    return NVSHMEMI_SUCCESS;

error:
    musaState = musaError;
    return NVSHMEMI_SYSTEM_ERROR;
}
