/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
* Copyright 2009-2022  NVIDIA Corporation.  All rights reserved.
*
* Licensed under the Apache License v2.0 with LLVM Exceptions.
* See https://llvm.org/LICENSE.txt for license information.
* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*/

#ifndef NVTX_IMPL_GUARD_CUDA
  #error Never include this file directly -- it is automatically included by nvToolsExtCuda.h (except when NVTX_NO_IMPL is defined).
#endif


#if defined __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef void (NVTX_API * nvtxNameCuDeviceA_impl_fntype)(MUdevice device, const char* name);
typedef void (NVTX_API * nvtxNameCuDeviceW_impl_fntype)(MUdevice device, const wchar_t* name);
typedef void (NVTX_API * nvtxNameCuContextA_impl_fntype)(MUcontext context, const char* name);
typedef void (NVTX_API * nvtxNameCuContextW_impl_fntype)(MUcontext context, const wchar_t* name);
typedef void (NVTX_API * nvtxNameCuStreamA_impl_fntype)(MUstream stream, const char* name);
typedef void (NVTX_API * nvtxNameCuStreamW_impl_fntype)(MUstream stream, const wchar_t* name);
typedef void (NVTX_API * nvtxNameCuEventA_impl_fntype)(MUevent event, const char* name);
typedef void (NVTX_API * nvtxNameCuEventW_impl_fntype)(MUevent event, const wchar_t* name);

NVTX_DECLSPEC void NVTX_API nvtxNameCuDeviceA(MUdevice device, const char* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuDeviceA_impl_fntype local = (nvtxNameCuDeviceA_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuDeviceA_impl_fnptr;
  if(local != 0)
  { (*local)(device, name); }
#endif /*NVTX_DISABLE*/
}

NVTX_DECLSPEC void NVTX_API nvtxNameCuDeviceW(MUdevice device, const wchar_t* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuDeviceW_impl_fntype local = (nvtxNameCuDeviceW_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuDeviceW_impl_fnptr;
  if(local != 0)
  { (*local)(device, name); }
#endif /*NVTX_DISABLE*/
}

NVTX_DECLSPEC void NVTX_API nvtxNameCuContextA(MUcontext context, const char* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuContextA_impl_fntype local = (nvtxNameCuContextA_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuContextA_impl_fnptr;
  if(local != 0)
  { (*local)(context, name); }
#endif /*NVTX_DISABLE*/
}

NVTX_DECLSPEC void NVTX_API nvtxNameCuContextW(MUcontext context, const wchar_t* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuContextW_impl_fntype local = (nvtxNameCuContextW_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuContextW_impl_fnptr;
  if(local != 0)
  { (*local)(context, name); }
#endif /*NVTX_DISABLE*/
}

NVTX_DECLSPEC void NVTX_API nvtxNameCuStreamA(MUstream stream, const char* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuStreamA_impl_fntype local = (nvtxNameCuStreamA_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuStreamA_impl_fnptr;
  if(local != 0)
  { (*local)(stream, name); }
#endif /*NVTX_DISABLE*/
}

NVTX_DECLSPEC void NVTX_API nvtxNameCuStreamW(MUstream stream, const wchar_t* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuStreamW_impl_fntype local = (nvtxNameCuStreamW_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuStreamW_impl_fnptr;
  if(local != 0)
  { (*local)(stream, name); }
#endif /*NVTX_DISABLE*/
}

NVTX_DECLSPEC void NVTX_API nvtxNameCuEventA(MUevent event, const char* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuEventA_impl_fntype local = (nvtxNameCuEventA_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuEventA_impl_fnptr;
  if(local != 0)
  { (*local)(event, name); }
#endif /*NVTX_DISABLE*/
}

NVTX_DECLSPEC void NVTX_API nvtxNameCuEventW(MUevent event, const wchar_t* name) {
#ifndef NVTX_DISABLE
  nvtxNameCuEventW_impl_fntype local = (nvtxNameCuEventW_impl_fntype)NVTX_VERSIONED_IDENTIFIER(nvtxGlobals).nvtxNameCuEventW_impl_fnptr;
  if(local != 0)
  { (*local)(event, name); }
#endif /*NVTX_DISABLE*/
}

#if defined __cplusplus
} /* extern "C" */
#endif /* __cplusplus */

