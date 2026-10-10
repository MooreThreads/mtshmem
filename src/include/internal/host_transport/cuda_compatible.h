/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2026-2026 Moore Threads Technology Co., Ltd.
 */

/*************************************************************************
 * Copyright (c) 2022-2023, Moore Threads CORPORATION. All rights reserved.
 *
 * See LICENSE.txt for license information
 ************************************************************************/

#ifndef NVSHMEM_CUDA_COMPATIBLE_H
#define NVSHMEM_CUDA_COMPATIBLE_H

#include <musa.h>
#include <musa_runtime.h>

#if MUSART_VERSION >= 99999
#include <musaTypedefs.h>
#endif

/* CU* -> MU* mapping for API compatibility (musawrap uses CU names only) */

/* Result and API */
#define CUresult     MUresult
#define CUDAAPI      MUSAAPI
#define CUDA_SUCCESS MUSA_SUCCESS

/* Scalar and handle types from MUSA headers */
#define CUdevice                         MUdevice
#define CUcontext                        MUcontext
#define CUmodule                         MUmodule
#define CUlibrary                        MUlibrary
#define CUstream                         MUstream
#define CUevent                          MUevent
#define CUarray                          MUarray
#define CUmipmappedArray                 MUmipmappedArray
#define CUdeviceptr                      MUdeviceptr
#define CUdevice_attribute               MUdevice_attribute
#define CUpointer_attribute              MUpointer_attribute
#define CUmemGenericAllocationHandle     MUmemGenericAllocationHandle
#define CUmemAllocationProp              MUmemAllocationProp
#define CUmemAllocationHandleType        MUmemAllocationHandleType
#define CUmemAllocationGranularity_flags MUmemAllocationGranularity_flags
#define CUmemAccessDesc                  MUmemAccessDesc
#define CUmemLocation                    MUmemLocation

/* Attributes */
#define CU_DEVICE_ATTRIBUTE_HANDLE_TYPE_FABRIC_SUPPORTED         MU_DEVICE_ATTRIBUTE_HANDLE_TYPE_FABRIC_SUPPORTED
#define CU_DEVICE_ATTRIBUTE_CAN_USE_64_BIT_STREAM_MEM_OPS        MU_DEVICE_ATTRIBUTE_CAN_USE_64_BIT_STREAM_MEM_OPS
#define CU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_FLUSH_WRITES_OPTIONS MU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_FLUSH_WRITES_OPTIONS
#define CU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_WRITES_ORDERING      MU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_WRITES_ORDERING
#define CU_DEVICE_ATTRIBUTE_CAN_FLUSH_REMOTE_WRITES              MU_DEVICE_ATTRIBUTE_CAN_FLUSH_REMOTE_WRITES
#define CU_DEVICE_ATTRIBUTE_MULTICAST_SUPPORTED                  MU_DEVICE_ATTRIBUTE_MULTICAST_SUPPORTED
#define CU_DEVICE_ATTRIBUTE_HOST_NUMA_ID                         MU_DEVICE_ATTRIBUTE_HOST_NUMA_ID
#define CU_DEVICE_ATTRIBUTE_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED \
    MU_DEVICE_ATTRIBUTE_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED
#define CU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_WITH_CUDA_VMM_SUPPORTED \
    MU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_WITH_MUSA_VMM_SUPPORTED

/* Stream and Event */
#define CU_CTX_SYNC_MEMOPS MU_CTX_SYNC_MEMOPS

#define CU_STREAM_WAIT_VALUE_EQ    MU_STREAM_WAIT_VALUE_EQ
#define CU_STREAM_WAIT_VALUE_GEQ   MU_STREAM_WAIT_VALUE_GEQ
#define CU_STREAM_WAIT_VALUE_FLUSH MU_STREAM_WAIT_VALUE_FLUSH

/* Memory */
#define CUipcMemHandle MUipcMemHandle

#define CU_MEM_ALLOCATION_TYPE_PINNED            MU_MEM_ALLOCATION_TYPE_PINNED
#define CU_MEM_LOCATION_TYPE_DEVICE              MU_MEM_LOCATION_TYPE_DEVICE
#define CU_MEM_LOCATION_TYPE_HOST_NUMA           MU_MEM_LOCATION_TYPE_HOST_NUMA
#define CU_MEM_HANDLE_TYPE_POSIX_FILE_DESCRIPTOR MU_MEM_HANDLE_TYPE_POSIX_FILE_DESCRIPTOR
#define CU_MEM_HANDLE_TYPE_FABRIC                MU_MEM_HANDLE_TYPE_FABRIC
#define CU_MEM_ALLOC_GRANULARITY_RECOMMENDED     MU_MEM_ALLOC_GRANULARITY_RECOMMENDED
#define CU_MEM_ACCESS_FLAGS_PROT_NONE            MU_MEM_ACCESS_FLAGS_PROT_NONE
#define CU_MEM_ACCESS_FLAGS_PROT_READ            MU_MEM_ACCESS_FLAGS_PROT_READ
#define CU_MEM_ACCESS_FLAGS_PROT_READWRITE       MU_MEM_ACCESS_FLAGS_PROT_READWRITE
#define CUmemAccess_flags_enum                   MUmemAccess_flags_enum

#define CU_MEMORYTYPE_DEVICE MU_MEMORYTYPE_DEVICE
#define CU_MEMORYTYPE_HOST   MU_MEMORYTYPE_HOST

#define CU_MULTICAST_GRANULARITY_RECOMMENDED     MU_MULTICAST_GRANULARITY_RECOMMENDED

/* Pointer */
#define CU_POINTER_ATTRIBUTE_SYNC_MEMOPS     MU_POINTER_ATTRIBUTE_SYNC_MEMOPS
#define CU_POINTER_ATTRIBUTE_MEMORY_TYPE     MU_POINTER_ATTRIBUTE_MEMORY_TYPE
#define CU_POINTER_ATTRIBUTE_DEVICE_ORDINAL  MU_POINTER_ATTRIBUTE_DEVICE_ORDINAL

/* GPUDirect */
#define CU_FLUSH_GPU_DIRECT_RDMA_WRITES_OPTION_HOST        MU_FLUSH_GPU_DIRECT_RDMA_WRITES_OPTION_HOST
#define CU_FLUSH_GPU_DIRECT_RDMA_WRITES_TARGET_CURRENT_CTX MU_FLUSH_GPU_DIRECT_RDMA_WRITES_TARGET_CURRENT_CTX
#define CU_FLUSH_GPU_DIRECT_RDMA_WRITES_TO_OWNER           MU_FLUSH_GPU_DIRECT_RDMA_WRITES_TO_OWNER


#define CUflushGPUDirectRDMAWritesTarget  MUflushGPUDirectRDMAWritesTarget
#define CUflushGPUDirectRDMAWritesScope   MUflushGPUDirectRDMAWritesScope

#if MUSART_VERSION >= 40200
#define CUmulticastGranularity_flags      MUmulticastGranularity_flags
#endif

#define cuuint64_t  muuint64_t
#define cuGetErrorString muGetErrorString

#endif /* NVSHMEM_CUDA_COMPATIBLE_H */
