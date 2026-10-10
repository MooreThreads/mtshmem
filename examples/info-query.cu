/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * Coverage: nvshmem_info_get_name, nvshmem_info_get_version,
 * nvshmemx_vendor_get_version_info, nvshmemx_my_pe, nvshmemx_n_pes.
 */
#include <stdio.h>
#include "nvshmem.h"
#include "nvshmemx.h"

#define NAME_BUF_LEN 256

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    nvshmem_init();

    int major = -1, minor = -1, patch = -1;
    char name[NAME_BUF_LEN];

    nvshmem_info_get_name(name);
    nvshmem_info_get_version(&major, &minor);
    int v_maj = -1, v_min = -1, v_patch = -1;
    nvshmemx_vendor_get_version_info(&v_maj, &v_min, &v_patch);

    if (nvshmem_my_pe() == 0) {
        printf("info_get_name: %s\n", name);
        printf("info_get_version: %d.%d\n", major, minor);
        printf("vendor_version: %d.%d.%d\n", v_maj, v_min, v_patch);
    }

    nvshmem_finalize();
    return 0;
}
