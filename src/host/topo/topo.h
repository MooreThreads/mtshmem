/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2016-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef __TOPO_H
#define __TOPO_H
#include <sched.h>                         // for cpu_set_t
#include "internal/host/nvshmemi_types.h"  // for nvshmemi_state_t

int nvshmemi_get_devices_by_distance(int *device_arr, int max_dev_per_pe,
                                     struct nvshmem_transport *tcurr);
int nvshmemi_detect_same_device(nvshmemi_state_t *state);
int nvshmemi_build_transport_map(nvshmemi_state_t *state);

// GPU topology helper functions
int get_gpu_pci_path(int gpu_device_id, char **path);
int get_numa_id_from_path(const char *path);
int parse_cpumap_to_cpuset(const char *cpumap_str, cpu_set_t *cpuset);

#endif
