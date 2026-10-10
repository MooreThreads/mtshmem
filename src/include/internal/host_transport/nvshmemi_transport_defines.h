/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2016-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef __NVSHMEMI_TRANSPORT_DEFINES_H
#define __NVSHMEMI_TRANSPORT_DEFINES_H

#define NVSHMEM_MEM_HANDLE_SIZE 512

#define NVSHMEM_PCIE_BDF_BUFFER_LEN 50

typedef struct pcie_identifier {
    int dev_id;
    int bus_id;
    int domain_id;
} pcie_id_t;

typedef struct nvshmem_mem_handle {
    char reserved[NVSHMEM_MEM_HANDLE_SIZE];
} nvshmem_mem_handle_t;

#endif
