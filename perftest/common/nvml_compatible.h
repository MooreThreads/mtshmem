/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef NVSHMEM_NVML_COMPATIBLE_H
#define NVSHMEM_NVML_COMPATIBLE_H

/*
 * NVML -> MTML compatibility layer for perftest module.
 *
 * This header provides NVML-style type and function names that map to
 * the MTML equivalents.
 *
 * Purpose: Reduce cherry-pick conflicts when porting upstream NVSHMEM
 * perftest code that uses NVML API names.
 *
 * This header is self-contained and includes mtml.h for base types.
 * It also defines MTML compatibility typedefs for older API versions.
 */

/* Include mtml.h for base MTML types */
#include <mtml.h>

/* ========== MTML Compatibility Typedefs ========== */

/*
 * MTML compatibility typedefs - needed when MTML API version < 12 or MUSA_VERSION < 12040.
 * These are defined with header guards to avoid conflicts with utils.cu.
 */

/* Header guard for MTML compatibility typedefs */
#ifndef MTSHMEM_MTML_COMPAT_TYPEDEF_H
#define MTSHMEM_MTML_COMPAT_TYPEDEF_H

#if ((MTML_API_VERSION < 12) || (MUSA_VERSION < 12040))
#ifndef MTML_GPU_FABRIC_STATE_COMPLETED
#define MTML_GPU_FABRIC_STATE_COMPLETED 3
#endif

#ifndef MTML_GPU_FABRIC_UUID_LEN
#define MTML_GPU_FABRIC_UUID_LEN 16
#endif

#ifndef mtmlGpuFabricInfo_v2
#define mtmlGpuFabricInfo_v2 (unsigned int)(sizeof(mtmlGpuFabricInfo_v2_t) | (2 << 24U))
#endif

/* MTML typedefs for older API versions */
typedef MtmlReturn mtmlReturn_t;
typedef unsigned char mtmlGpuFabricState_t;
typedef struct mtmlGpuFabricInfo_v2_t_ {
    unsigned int version;
    unsigned char clusterUuid[MTML_GPU_FABRIC_UUID_LEN];
    mtmlReturn_t status;
    unsigned int cliqueId;
    mtmlGpuFabricState_t state;
    unsigned int healthMask;
} mtmlGpuFabricInfo_v2_t;

typedef MtmlLibrary *mtmlLibrary_t;
typedef MtmlDevice *mtmlDevice_t;
typedef mtmlGpuFabricInfo_v2_t mtmlGpuFabricInfoV_t;

#else /* MTML_API_VERSION >= 12 && MUSA_VERSION >= 12040 */
/* Modern MTML provides these types directly - use typedefs to ensure they exist */
#ifndef mtmlReturn_t
typedef MtmlReturn mtmlReturn_t;
#endif
#ifndef mtmlDevice_t
typedef MtmlDevice *mtmlDevice_t;
#endif
#ifndef mtmlLibrary_t
typedef MtmlLibrary *mtmlLibrary_t;
#endif
/* For modern MTML, mtmlGpuFabricInfoV_t should be defined in mtml.h */
#ifndef mtmlGpuFabricInfoV_t
typedef mtmlGpuFabricInfo_v2_t mtmlGpuFabricInfoV_t;
#endif

#endif /* MTML_API_VERSION check */

/* P2P types - these may not be defined in MTML, use int as fallback */
#ifndef mtmlGpuP2PCapsIndex_enum
typedef int mtmlGpuP2PCapsIndex_enum;
#endif
#ifndef mtmlGpuP2PStatus_t
typedef int mtmlGpuP2PStatus_t;
#endif

/* P2P status values */
#ifndef MTML_P2P_STATUS_OK
#define MTML_P2P_STATUS_OK         0
#endif
#ifndef MTML_P2P_STATUS_NOSUP
#define MTML_P2P_STATUS_NOSUP      1
#endif

#endif /* MTSHMEM_MTML_COMPAT_TYPEDEF_H */

/* ========== NVML -> MTML Type Mappings ========== */

/* Return and device types */
#define nvmlReturn_t               mtmlReturn_t
#define nvmlDevice_t               mtmlDevice_t
#define nvmlLibrary_t              mtmlLibrary_t

/* Fabric info types */
#define nvmlGpuFabricInfoV_t       mtmlGpuFabricInfoV_t
#define nvmlGpuFabricInfo_v2_t     mtmlGpuFabricInfo_v2_t
#define nvmlGpuFabricState_t       mtmlGpuFabricState_t

/* P2P types */
#define nvmlGpuP2PCapsIndex_enum   mtmlGpuP2PCapsIndex_enum
#define nvmlGpuP2PStatus_t         mtmlGpuP2PStatus_t
#define NVML_P2P_STATUS_OK         MTML_P2P_STATUS_OK
#define NVML_P2P_STATUS_NOSUP      MTML_P2P_STATUS_NOSUP

/* Return codes */
#ifndef NVML_SUCCESS
#define NVML_SUCCESS               ((nvmlReturn_t)0)
#endif

/* Fabric constants */
#define NVML_GPU_FABRIC_STATE_COMPLETED  MTML_GPU_FABRIC_STATE_COMPLETED
#define NVML_GPU_FABRIC_UUID_LEN         MTML_GPU_FABRIC_UUID_LEN

/* Fabric info version macro */
#define nvmlGpuFabricInfo_v2       mtmlGpuFabricInfo_v2

/* ========== NVML Function Table ========== */

/*
 * NVML function table for perftest compatibility.
 * This matches the upstream NVSHMEM perftest nvml_function_table structure.
 * The actual implementation loads MTML functions via dlsym.
 */
struct nvml_function_table {
    mtmlReturn_t (*nvmlInit)(void);
    mtmlReturn_t (*nvmlShutdown)(void);
    mtmlReturn_t (*nvmlDeviceGetHandleByPciBusId)(const char *pciBusId, mtmlDevice_t *device);
    mtmlReturn_t (*nvmlDeviceGetP2PStatus)(mtmlDevice_t device1, mtmlDevice_t device2,
                                           mtmlGpuP2PCapsIndex_enum caps,
                                           mtmlGpuP2PStatus_t *p2pStatus);
    mtmlReturn_t (*nvmlDeviceGetGpuFabricInfoV)(mtmlDevice_t device, mtmlGpuFabricInfoV_t *info);
};

/* Function table init/fini declarations (implemented in utils.cu) */
extern void *nvml_handle;
extern struct nvml_function_table nvml_ftable;
extern const char *env_value;

int nvshmemi_nvml_ftable_init(struct nvml_function_table *nvml_ftable, void **nvml_handle);
void nvshmemi_nvml_ftable_fini(struct nvml_function_table *nvml_ftable, void **nvml_handle);

#endif /* NVSHMEM_NVML_COMPATIBLE_H */