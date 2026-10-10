/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * Covers nvshmemx_buffer_register / nvshmemx_buffer_unregister for different
 * memory types: pageable (malloc), pinned (musaMallocHost), vidmem (musaMalloc),
 * symmem (nvshmem_malloc). Each type is a small case in a function; register
 * failure does not exit the program, the next memory type is tried. Exit after
 * all types have been tried.
 */
#include <stdio.h>
#include <stdlib.h>
#include "nvshmem.h"
#include "nvshmemx.h"

static const size_t k_buf_size = 4096;

/* Pageable memory: malloc. Returns 1 on success, 0 on failure (no program exit). */
static int try_pageable(int mype) {
    void *ptr = malloc(k_buf_size);
    if (!ptr) {
        fprintf(stderr, "PE %d: pageable malloc failed\n", mype);
        return 0;
    }
    if (nvshmemx_buffer_register(ptr, k_buf_size) != 0) {
        fprintf(stderr, "PE %d: buffer_register(pageable) failed\n", mype);
        free(ptr);
        return 0;
    }
    if (nvshmemx_buffer_unregister(ptr) != 0) {
        fprintf(stderr, "PE %d: buffer_unregister(pageable) failed\n", mype);
    }
    printf("PE %d: pageable buffer_register/unregister succeeded\n", mype);
    free(ptr);
    return 1;
}

/* Pinned memory: musaMallocHost. Returns 1 on success, 0 on failure. */
static int try_pinned(int mype) {
    void *ptr = NULL;
    if (musaMallocHost(&ptr, k_buf_size) != musaSuccess) {
        fprintf(stderr, "PE %d: musaMallocHost failed\n", mype);
        return 0;
    }
    if (nvshmemx_buffer_register(ptr, k_buf_size) != 0) {
        fprintf(stderr, "PE %d: buffer_register(pinned) failed\n", mype);
        musaFreeHost(ptr);
        return 0;
    }
    if (nvshmemx_buffer_unregister(ptr) != 0) {
        fprintf(stderr, "PE %d: buffer_unregister(pinned) failed\n", mype);
    }
    printf("PE %d: pinned buffer_register/unregister succeeded\n", mype);
    musaFreeHost(ptr);
    return 1;
}

/* Device memory (vidmem): musaMalloc. Returns 1 on success, 0 on failure. */
static int try_vidmem(int mype) {
    void *ptr = NULL;
    if (musaMalloc(&ptr, k_buf_size) != musaSuccess) {
        fprintf(stderr, "PE %d: musaMalloc failed\n", mype);
        return 0;
    }
    if (nvshmemx_buffer_register(ptr, k_buf_size) != 0) {
        fprintf(stderr, "PE %d: buffer_register(vidmem) failed\n", mype);
        musaFree(ptr);
        return 0;
    }
    if (nvshmemx_buffer_unregister(ptr) != 0) {
        fprintf(stderr, "PE %d: buffer_unregister(vidmem) failed\n", mype);
    }
    printf("PE %d: vidmem buffer_register/unregister succeeded\n", mype);
    musaFree(ptr);
    return 1;
}

/* Symmetric memory: nvshmem_malloc. Returns 1 on success, 0 on failure. */
static int try_symmem(int mype) {
    void *ptr = nvshmem_malloc(k_buf_size);
    if (!ptr) {
        fprintf(stderr, "PE %d: nvshmem_malloc failed\n", mype);
        return 0;
    }
    if (nvshmemx_buffer_register(ptr, k_buf_size) != 0) {
        fprintf(stderr, "PE %d: buffer_register(symmem) failed\n", mype);
        nvshmem_free(ptr);
        return 0;
    }
    if (nvshmemx_buffer_unregister(ptr) != 0) {
        fprintf(stderr, "PE %d: buffer_unregister(symmem) failed\n", mype);
    }
    nvshmem_free(ptr);
    printf("PE %d: symmem buffer_register/unregister succeeded\n", mype);
    return 1;
}

int main(int argc, char **argv) {
    int any_ok = 0;

    nvshmem_init();

    int mype = nvshmem_my_pe();
    int mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);

    if (musaSetDevice(mype_node) != musaSuccess) {
        fprintf(stderr, "PE %d: musaSetDevice failed\n", mype);
        nvshmem_finalize();
        return 1;
    }

    if (try_symmem(mype)) any_ok = 1;
    if (try_pageable(mype)) any_ok = 1;
    if (try_pinned(mype)) any_ok = 1;
    if (try_vidmem(mype)) any_ok = 1;

    nvshmemx_buffer_unregister_all();
    nvshmem_finalize();
    return any_ok ? 0 : 1;
}
