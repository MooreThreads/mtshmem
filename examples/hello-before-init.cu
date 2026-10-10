/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * 用于覆盖 "nvshmem API called before nvshmem_init" 路径。
 * 不调用 nvshmem_init()，直接启动调用 device API 的 kernel，触发
 * nvshmemi_check_state_and_init_d() 中的 NVSHMEMI_ERROR_EXIT。
 * See COPYRIGHT for license information.
 */
#include <stdio.h>
#include "nvshmem.h"
#include "nvshmemx.h"

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    /* 故意不调用 nvshmem_init() */
    musaSetDevice(0);
    int* symm_ptr = (int*)nvshmem_malloc(sizeof(int));
    musaDeviceSynchronize();
    return 0;  /* 若走到此处说明未触发 ERROR_EXIT，异常 */
}
