/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef NVSHMEM_CUDA_RUNTIME_COMPATIBLE_H
#define NVSHMEM_CUDA_RUNTIME_COMPATIBLE_H

#include <musa_fp16.h>
#include <musa_bf16.h>
#include <musa_runtime.h>
#include <musa_runtime_api.h>
#include <driver_types.h>

/* CUDA Compiler Macros -> MUSA Compiler Macros */
#ifdef __MUSA_ARCH__
#define __CUDA_ARCH__ __MUSA_ARCH__
#endif

#ifdef __MUSACC__
#define __CUDACC__ __MUSACC__
#endif

#ifdef __MUSACC_RDC__
#define __CUDACC_RDC__ __MUSACC_RDC__
#endif

#ifdef __MUSACC_RTC__
#define __CUDACC_RTC__ __MUSACC_RTC__
#endif

#ifdef MUSARTAPI
#define CUDARTAPI MUSARTAPI
#endif

#define CUDART_VERSION MUSART_VERSION
#define __nv_bfloat16 __mt_bfloat16

/* CUDA Runtime API -> MUSA Runtime API (internal sources use cuda* names) */

/* Error and result */
#define cudaError_t           musaError_t
#define cudaGetErrorString    musaGetErrorString
#define cudaGetLastError      musaGetLastError

#define cudaSuccess                     musaSuccess
#define cudaErrorInvalidValue           musaErrorInvalidValue
#define cudaErrorInvalidSymbol          musaErrorInvalidSymbol
#define cudaErrorInvalidMemcpyDirection musaErrorInvalidMemcpyDirection
#define cudaErrorNoKernelImageForDevice musaErrorNoKernelImageForDevice

/* Device */
#define cudaGetDevice                    musaGetDevice
#define cudaGetDeviceCount               musaGetDeviceCount
#define cudaDeviceSynchronize            musaDeviceSynchronize
#define cudaDeviceGetAttribute           musaDeviceGetAttribute
#define cudaDeviceGetStreamPriorityRange musaDeviceGetStreamPriorityRange
#define cudaDeviceGetPCIBusId            musaDeviceGetPCIBusId
#define cudaGetDeviceProperties          musaGetDeviceProperties
#define cudaDeviceCanAccessPeer          musaDeviceCanAccessPeer
#define cudaDeviceGetP2PAttribute        musaDeviceGetP2PAttribute
#define cudaDeviceProp                   musaDeviceProp

#define cudaUUID_t musaUUID_t

#define cudaDevAttrWarpSize                          musaDevAttrWarpSize
#define cudaDevAttrMaxThreadsPerBlock                musaDevAttrMaxThreadsPerBlock
#define cudaDevAttrMultiProcessorCount               musaDevAttrMultiProcessorCount
#define cudaDevP2PAttrNativeAtomicSupported          musaDevP2PAttrNativeAtomicSupported
#define cudaDevAttrCanUseHostPointerForRegisteredMem musaDevAttrCanUseHostPointerForRegisteredMem

/* Stream and event */
#define cudaStream_t                  musaStream_t
#define cudaEvent_t                   musaEvent_t
#define cudaStreamCreateWithPriority  musaStreamCreateWithPriority
#define cudaStreamCreateWithFlags     musaStreamCreateWithFlags
#define cudaStreamDestroy             musaStreamDestroy
#define cudaStreamSynchronize         musaStreamSynchronize
#define cudaStreamWaitEvent           musaStreamWaitEvent

#define cudaStreamNonBlocking         musaStreamNonBlocking
#define cudaEventCreate               musaEventCreate
#define cudaEventCreateWithFlags      musaEventCreateWithFlags
#define cudaEventDestroy              musaEventDestroy
#define cudaEventRecord               musaEventRecord
#define cudaEventDisableTiming        musaEventDisableTiming
#define cudaEventDefault              musaEventDefault
#define cudaEventInterprocess         musaEventInterprocess

/* Symbol */
#define cudaGetSymbolAddress musaGetSymbolAddress

/* Module */
#define cudaLaunchKernel             musaLaunchKernel
#define cudaLaunchCooperativeKernel  musaLaunchCooperativeKernel

#define cudaDevAttrCooperativeLaunch musaDevAttrCooperativeLaunch

/* Memory */
#define cudaMalloc                musaMalloc
#define cudaFree                  musaFree
#define cudaMallocHost            musaMallocHost
#define cudaFreeHost              musaFreeHost
#define cudaMallocManaged         musaMallocManaged
#define cudaHostAlloc             musaHostAlloc
#define cudaHostRegister          musaHostRegister
#define cudaHostUnregister        musaHostUnregister
#define cudaHostGetDevicePointer  musaHostGetDevicePointer
#define cudaHostRegisterDefault   musaHostRegisterDefault
#define cudaHostRegisterPortable  musaHostRegisterPortable
#define cudaHostRegisterMapped    musaHostRegisterMapped
#define cudaHostRegisterIoMemory  musaHostRegisterIoMemory
#define cudaHostAllocPortable     musaHostAllocPortable
#define cudaHostAllocMapped       musaHostAllocMapped
#define cudaDeviceSetLimit        musaDeviceSetLimit
#define cudaLimitStackSize        musaLimitStackSize

#define cudaMemcpy               musaMemcpy
#define cudaMemcpyAsync          musaMemcpyAsync
#define cudaMemset               musaMemset
#define cudaMemsetAsync          musaMemsetAsync
#define cudaMemcpy2D             musaMemcpy2D
#define cudaMemcpy2DAsync        musaMemcpy2DAsync

#define cudaMemcpyHostToDevice   musaMemcpyHostToDevice
#define cudaMemcpyDeviceToHost   musaMemcpyDeviceToHost
#define cudaMemcpyDeviceToDevice musaMemcpyDeviceToDevice
#define cudaMemcpyDefault        musaMemcpyDefault

/* Pointer */
#define cudaPointerGetAttributes   musaPointerGetAttributes
#define cudaPointerAttributes      musaPointerAttributes
#define cudaMemoryType             musaMemoryType
#define cudaMemoryTypeUnregistered musaMemoryTypeUnregistered
#define cudaMemoryTypeDevice       musaMemoryTypeDevice
#define cudaMemoryTypeManaged      musaMemoryTypeManaged
#define cudaArray_t                 musaArray_t
#define cudaMipmappedArray_t        musaMipmappedArray_t
#define cudaArrayGetInfo            musaArrayGetInfo
#define cudaMallocArray             musaMallocArray
#define cudaMalloc3DArray           musaMalloc3DArray

/* IPC */
#define cudaIpcGetEventHandle          musaIpcGetEventHandle
#define cudaIpcOpenEventHandle         musaIpcOpenEventHandle
#define cudaIpcGetMemHandle            musaIpcGetMemHandle
#define cudaIpcOpenMemHandle           musaIpcOpenMemHandle
#define cudaIpcCloseMemHandle          musaIpcCloseMemHandle
#define cudaIpcEventHandle_t           musaIpcEventHandle_t
#define cudaIpcMemHandle_t             musaIpcMemHandle_t
#define cudaIpcMemLazyEnablePeerAccess musaIpcMemLazyEnablePeerAccess

/* Graph */
#define cudaStreamIsCapturing          musaStreamIsCapturing
#define cudaStreamBeginCapture         musaStreamBeginCapture
#define cudaStreamEndCapture           musaStreamEndCapture
#define cudaGraphInstantiate           musaGraphInstantiate
#define cudaGraphLaunch                musaGraphLaunch
#define cudaGraphExecDestroy           musaGraphExecDestroy
#define cudaGraphDestroy               musaGraphDestroy

#define cudaStreamCaptureStatus            musaStreamCaptureStatus
#define cudaStreamCaptureStatusNone        musaStreamCaptureStatusNone
#define cudaStreamCaptureStatusActive      musaStreamCaptureStatusActive
#define cudaStreamCaptureStatusInvalidated musaStreamCaptureStatusInvalidated
#define cudaStreamCaptureModeGlobal        musaStreamCaptureModeGlobal

#define cudaGraph_t     musaGraph_t
#define cudaGraphExec_t musaGraphExec_t

/* Callback */
#define cudaStreamAddCallback musaStreamAddCallback

/* Version */
#define cudaDriverGetVersion  musaDriverGetVersion
#define cudaRuntimeGetVersion musaRuntimeGetVersion

#define cudaDeviceScheduleBlockingSync musaDeviceScheduleBlockingSync
#define cudaDeviceScheduleSpin musaDeviceScheduleSpin
#define cudaDeviceScheduleYield musaDeviceScheduleYield
#define cudaDeviceScheduleBlockUntilEventComplete musaDeviceScheduleBlockUntilEventComplete
#define cudaDeviceScheduleAuto musaDeviceScheduleAuto
#define cudaDeviceScheduleThreadBlock musaDeviceScheduleThreadBlock
#define cudaDeviceScheduleBlockUntilEventComplete musaDeviceScheduleBlockUntilEventComplete

/* Occupancy */
#define cudaOccupancyMaxPotentialBlockSize musaOccupancyMaxPotentialBlockSize
/* MUSA runtime only exports WithFlags; redirect 4-arg call to WithFlags(..., cudaOccupancyDefault) */
#define cudaOccupancyMaxActiveBlocksPerMultiprocessor(a, b, c, d) \
    cudaOccupancyMaxActiveBlocksPerMultiprocessorWithFlags(a, b, c, d, cudaOccupancyDefault)
#define cudaOccupancyMaxActiveBlocksPerMultiprocessorWithFlags musaOccupancyMaxActiveBlocksPerMultiprocessorWithFlags

#define cudaOccupancyDefault                musaOccupancyDefault
#define cudaOccupancyDisableCachingOverride musaOccupancyDisableCachingOverride

#endif /* NVSHMEM_CUDA_RUNTIME_COMPATIBLE_H */
