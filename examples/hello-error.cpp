/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * 基于 hello 的用例，用于覆盖错误码/边界路径（如 malloc 失败、非法参数等）。
 * See COPYRIGHT for license information.
 */
#include <stdio.h>
#include "nvshmem.h"
#include "nvshmemx.h"

int main(int argc, char **argv) {
    nvshmem_init();
    int mype = nvshmem_my_pe();
    int npes = nvshmem_n_pes();
    if (npes < 1) {
        nvshmem_finalize();
        return 1;
    }
    int mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    musaSetDevice(mype_node);

    /* 请求过大可能触发 NVSHMEMX_ERROR_OUT_OF_MEMORY 或返回 NULL */
    size_t huge = (size_t)(1ULL << 40);
    void *ptr = nvshmem_malloc(huge);
    if (ptr == NULL) {
        /* 覆盖库内错误返回路径 */
        nvshmem_finalize();
        return 0;
    }
    nvshmem_free(ptr);
    nvshmem_finalize();
    return 0;
}
