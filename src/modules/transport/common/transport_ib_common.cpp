/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2022, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
#include "transport_ib_common.h"
#include <assert.h>                            // for assert
#include <dlfcn.h>                             // for dlclose, dlopen, RTLD_LAZY
#include <errno.h>                             // for errno
#include <infiniband/verbs.h>                  // for IBV_ACCESS_LOCAL_WRITE, IBV_ACCESS_...
#include <stdint.h>                            // for uintptr_t, uint64_t
#include <string.h>                            // for strerror
#include <unistd.h>                            // for access, close, sysconf, F_OK, _SC_P...
#include "internal/host/cuda_runtime_compatible.h"
#include "internal/host_transport/musawrap.h"  // for nvshmemi_cuda_fn_table, CUCHECKGOTO
#include "non_abi/nvshmemx_error.h"            // for NVSHMEMX_ERROR_INTERNAL, NVSHMEMX_S...
#include "transport_common.h"                  // for LOAD_SYM, INFO, MAXPATHSIZE

int nvshmemt_ib_common_nv_peer_mem_available() {
    // if (access("/sys/kernel/mm/memory_peers/nv_mem/version", F_OK) == 0) {
    //     return NVSHMEMX_SUCCESS;
    // }
    if (access("/sys/kernel/mm/memory_peers/mt_peermem/version", F_OK) == 0) {
        return NVSHMEMX_SUCCESS;
    }
    if (access("/sys/module/mt_peermem/version", F_OK) == 0) {
        return NVSHMEMX_SUCCESS;
    }

    return NVSHMEMX_ERROR_INTERNAL; // LCOV_EXCL_LINE
}

int nvshmemt_ib_common_reg_mem_handle(struct nvshmemt_ibv_function_table *ftable, struct ibv_pd *pd,
                                      nvshmem_mem_handle_t *mem_handle, void *buf, size_t length,
                                      bool local_only, bool dmabuf_support,
                                      struct nvshmemi_cuda_fn_table *table, int log_level,
                                      bool relaxed_ordering, void *alias_va_ptr) {
    struct nvshmemt_ib_common_mem_handle *handle =
        (struct nvshmemt_ib_common_mem_handle *)mem_handle;
    struct ibv_mr *mr = NULL;
    int status = 0;
    int ro_flag = 0;
    bool host_memory = false;

    assert(sizeof(struct nvshmemt_ib_common_mem_handle) <= NVSHMEM_MEM_HANDLE_SIZE);

    cudaPointerAttributes attr;
    status = cudaPointerGetAttributes(&attr, buf);
    if (status != cudaSuccess) {
        host_memory = true;  // LCOV_EXCL_LINE
        status = 0;          // LCOV_EXCL_LINE
        cudaGetLastError();  // LCOV_EXCL_LINE
    } else if (attr.type != cudaMemoryTypeDevice) {
        host_memory = true;
    }

#if defined(HAVE_IBV_ACCESS_RELAXED_ORDERING)
#if HAVE_IBV_ACCESS_RELAXED_ORDERING == 1
    // IBV_ACCESS_RELAXED_ORDERING has been introduced to rdma-core since v28.0.
    if (relaxed_ordering) {
        ro_flag = IBV_ACCESS_RELAXED_ORDERING;
    }
#endif
#endif

    if (ftable->reg_dmabuf_mr != NULL && !host_memory && dmabuf_support &&
        CUPFN(table, cuMemGetHandleForAddressRange)) {
        size_t page_size = sysconf(_SC_PAGESIZE);
        size_t size_aligned;
        CUdeviceptr p;
        p = (CUdeviceptr)((uintptr_t)buf & ~(page_size - 1));
        size_aligned =
            ((length + (uintptr_t)buf - (uintptr_t)p + page_size - 1) / page_size) * page_size;
        CUCHECKGOTO(table,
                    cuMemGetHandleForAddressRange(&handle->fd, (CUdeviceptr)p, size_aligned,
                                                  CU_MEM_RANGE_HANDLE_TYPE_DMA_BUF_FD, 0),
                    status, out);

        mr = ftable->reg_dmabuf_mr(pd, 0, size_aligned, (uint64_t)p, handle->fd,
                                   IBV_ACCESS_LOCAL_WRITE | IBV_ACCESS_REMOTE_WRITE |
                                       IBV_ACCESS_REMOTE_READ | IBV_ACCESS_REMOTE_ATOMIC | ro_flag);
        if (mr == NULL) {
            close(handle->fd);       // LCOV_EXCL_LINE
            goto reg_dmabuf_failure; // LCOV_EXCL_LINE
        }                            // LCOV_EXCL_LINE

        INFO(log_level, "ibv_reg_dmabuf_mr handle %p handle->mr %p, with relaxed ordering flag: %d", handle, handle->mr, ro_flag);
    } else {
    reg_dmabuf_failure:

        handle->fd = 0;
        if (alias_va_ptr) {
            mr = ftable->reg_mr_iova(pd, alias_va_ptr, length, (uint64_t)buf,
                                     IBV_ACCESS_LOCAL_WRITE | IBV_ACCESS_REMOTE_WRITE |
                                         IBV_ACCESS_REMOTE_READ | IBV_ACCESS_REMOTE_ATOMIC |
                                         ro_flag);
            INFO(log_level,
                 "ibv_reg_mr_iova handle %p handle->mr %p, with relaxed ordering flag: %d",
                 handle, handle->mr, ro_flag);
        } else {
            mr = ftable->reg_mr(pd, buf, length,
                                IBV_ACCESS_LOCAL_WRITE | IBV_ACCESS_REMOTE_WRITE |
                                    IBV_ACCESS_REMOTE_READ | IBV_ACCESS_REMOTE_ATOMIC | ro_flag);
            INFO(log_level,
                 "ibv_reg_mr handle %p handle->mr %p, with relaxed ordering flag: %d", handle,
                 handle->mr, ro_flag);
        }
        NVSHMEMI_NULL_ERROR_JMP(mr, status, NVSHMEMX_ERROR_OUT_OF_MEMORY, out,
                                "mem registration failed. Reason: %s\n", strerror(errno));
    }

    handle->buf = buf;
    handle->lkey = mr->lkey;
    handle->rkey = mr->rkey;
    handle->mr = mr;
    handle->local_only = local_only;

out:
    return status;
}

int nvshmemt_ib_common_release_mem_handle(struct nvshmemt_ibv_function_table *ftable,
                                          nvshmem_mem_handle_t *mem_handle, int log_level) {
    int status = 0;
    struct nvshmemt_ib_common_mem_handle *handle =
        (struct nvshmemt_ib_common_mem_handle *)mem_handle;

    INFO(log_level, "ibv_dereg_mr handle %p handle->mr %p", handle, handle->mr);
    if (handle->mr) {
        status = ftable->dereg_mr((struct ibv_mr *)handle->mr);
        if (handle->fd) close(handle->fd);
    }
    NVSHMEMI_NZ_ERROR_JMP(status, NVSHMEMX_ERROR_INTERNAL, out, "ibv_dereg_mr failed \n");

out:
    return status;
}

int nvshmemt_ib_iface_get_mlx_path(const char *ib_name, char **path) {
    int status;

    char device_path[MAXPATHSIZE];
    status = snprintf(device_path, MAXPATHSIZE, "/sys/class/infiniband/%s/device", ib_name);
    if (status < 0 || status >= MAXPATHSIZE) {
        NVSHMEMI_ERROR_JMP(status, NVSHMEMX_ERROR_INTERNAL, out,
                           "Unable to fill in device name.\n");
    } else {
        status = NVSHMEMX_SUCCESS;
    }

    *path = realpath(device_path, NULL);
    NVSHMEMI_NULL_ERROR_JMP(*path, status, NVSHMEMX_ERROR_OUT_OF_MEMORY, out, "realpath failed \n");

out:
    return status;
}

int nvshmemt_ibv_ftable_init(void **ibv_handle, struct nvshmemt_ibv_function_table *ftable,
                             int log_level) {
    *ibv_handle = dlopen("libibverbs.so.1", RTLD_LAZY);
    if (*ibv_handle == NULL) {
        INFO(log_level, "libibverbs not found on the system.");
        return -1;
    }

    LOAD_SYM(*ibv_handle, "ibv_fork_init", ftable->fork_init);
    LOAD_SYM(*ibv_handle, "ibv_create_ah", ftable->create_ah);
    LOAD_SYM(*ibv_handle, "ibv_get_device_list", ftable->get_device_list);
    LOAD_SYM(*ibv_handle, "ibv_get_device_name", ftable->get_device_name);
    LOAD_SYM(*ibv_handle, "ibv_open_device", ftable->open_device);
    LOAD_SYM(*ibv_handle, "ibv_close_device", ftable->close_device);
    LOAD_SYM(*ibv_handle, "ibv_query_port", ftable->query_port);
    LOAD_SYM(*ibv_handle, "ibv_query_device", ftable->query_device);
    LOAD_SYM(*ibv_handle, "ibv_alloc_pd", ftable->alloc_pd);
    LOAD_SYM(*ibv_handle, "ibv_reg_mr", ftable->reg_mr);
    LOAD_SYM(*ibv_handle, "ibv_reg_mr_iova", ftable->reg_mr_iova);
    LOAD_SYM(*ibv_handle, "ibv_reg_dmabuf_mr", ftable->reg_dmabuf_mr);
    LOAD_SYM(*ibv_handle, "ibv_dereg_mr", ftable->dereg_mr);
    LOAD_SYM(*ibv_handle, "ibv_create_cq", ftable->create_cq);
    LOAD_SYM(*ibv_handle, "ibv_create_qp", ftable->create_qp);
    LOAD_SYM(*ibv_handle, "ibv_create_srq", ftable->create_srq);
    LOAD_SYM(*ibv_handle, "ibv_modify_qp", ftable->modify_qp);
    LOAD_SYM(*ibv_handle, "ibv_query_gid", ftable->query_gid);
    LOAD_SYM(*ibv_handle, "ibv_dealloc_pd", ftable->dealloc_pd);
    LOAD_SYM(*ibv_handle, "ibv_destroy_qp", ftable->destroy_qp);
    LOAD_SYM(*ibv_handle, "ibv_destroy_cq", ftable->destroy_cq);
    LOAD_SYM(*ibv_handle, "ibv_destroy_srq", ftable->destroy_srq);
    LOAD_SYM(*ibv_handle, "ibv_destroy_ah", ftable->destroy_ah);

    return 0;
}

void nvshmemt_ibv_ftable_fini(void **ibv_handle) {
    int status;

    if (ibv_handle) {
        status = dlclose(*ibv_handle);
        if (status) {
            NVSHMEMI_ERROR_PRINT("Unable to close libibverbs handle.");
        }
    }
}
