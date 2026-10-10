/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */
/*
 * Copyright (c) 2022-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef MTML_WRAP_H
#define MTML_WRAP_H

#include <musa.h>
#include <mtml.h>

/* Copied from MUSA 12.4 MTML header. */
#if ((MTML_API_VERSION < 12) || (MUSA_VERSION < 12040))

#ifndef MTML_GPU_FABRIC_STATE_COMPLETED
#define MTML_GPU_FABRIC_STATE_COMPLETED 3
#endif

#ifndef mtmlGpuFabricInfo_v2
#define mtmlGpuFabricInfo_v2 (unsigned int)(sizeof(mtmlGpuFabricInfo_v2_t) | (2 << 24U))
#endif

#ifndef MTML_GPU_FABRIC_UUID_LEN
#define MTML_GPU_FABRIC_UUID_LEN 16
#endif

#ifndef MTML_CONFIG_MAGIC_NUM
#define MTML_CONFIG_MAGIC_NUM 1000
#endif

typedef MtmlReturn mtmlReturn_t;
typedef unsigned char mtmlGpuFabricState_t;
typedef struct {
    unsigned int version;  //!< Structure version identifier (set to \ref mtmlGpuFabricInfo_v2)
    unsigned char
        clusterUuid[MTML_GPU_FABRIC_UUID_LEN];  //!< Uuid of the cluster to which this GPU belongs
    mtmlReturn_t
        status;  //!< Error status, if any. Must be checked only if state returns "complete".
    unsigned int cliqueId;       //!< ID of the fabric clique to which this GPU belongs
    mtmlGpuFabricState_t state;  //!< Current state of GPU registration process
    unsigned int healthMask;     //!< GPU Fabric health Status Mask
} mtmlGpuFabricInfo_v2_t;

typedef MtmlLibrary* mtmlLibrary_t;
typedef MtmlDevice* mtmlDevice_t;
typedef MtmlDeviceP2PCaps mtmlGpuP2PCapsIndex_enum;
typedef MtmlDeviceP2PStatus mtmlGpuP2PStatus_t;
typedef mtmlGpuFabricInfo_v2_t mtmlGpuFabricInfoV_t;
typedef MtmlLogConfiguration mtmlLogConfiguration_t;
#endif
/* end MTML Header defs. */

struct nvml_function_table {
    mtmlReturn_t (*mtmlLibraryInit)(mtmlLibrary_t *lib);
    mtmlReturn_t (*mtmlLibraryShutDown)(mtmlLibrary_t lib);
    mtmlReturn_t (*mtmlLibraryInitDeviceByPciSbdf)(const mtmlLibrary_t lib, const char *pciBusId, mtmlDevice_t *device);
    mtmlReturn_t (*mtmlDeviceGetP2PStatus)(mtmlDevice_t device1, mtmlDevice_t device2,
                                         mtmlGpuP2PCapsIndex_enum caps,
                                         mtmlGpuP2PStatus_t *p2pStatus);
    mtmlReturn_t (*mtmlDeviceCountMtLinkLayouts)(mtmlDevice_t device1, mtmlDevice_t device2,
                                               unsigned int *linkCount);
    mtmlReturn_t (*mtmlDeviceGetGpuFabricInfoV)(mtmlDevice_t device, mtmlGpuFabricInfoV_t *info);
    mtmlReturn_t (*mtmlLogGetConfiguration)(mtmlLogConfiguration_t *config);
    mtmlReturn_t (*mtmlLogSetConfiguration)(const mtmlLogConfiguration_t *config);
};

int nvshmemi_nvml_ftable_init(struct nvml_function_table *mtml_ftable, void **mtml_handle);
void nvshmemi_nvml_ftable_fini(struct nvml_function_table *mtml_ftable, void **mtml_handle);

#endif
