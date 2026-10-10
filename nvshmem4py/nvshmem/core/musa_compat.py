# Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

"""
Small MUSA compatibility surface for the core nvshmem4py APIs.

The upstream package uses cuda.core.experimental for Device, Stream, Buffer,
and MemoryResource. MTSHMEM does not require CUDA Python for the first MUSA
binding milestone, so this module provides the minimal behavior needed by
init/fini, symmetric memory, and raw on-stream APIs.
"""

from types import SimpleNamespace
import ctypes
import os
import time

_musart = None


def _musart_candidates():
    override = os.environ.get("NVSHMEM4PY_MUSART_LIBRARY")
    if override:
        yield override

    musa_home = os.environ.get("MUSA_HOME") or "/usr/local/musa"
    yield os.path.join(musa_home, "lib64", "libmusart.so")
    yield os.path.join(musa_home, "lib", "libmusart.so")
    yield "libmusart.so"


def _load_musart():
    global _musart
    if _musart is not None:
        return _musart

    errors = []
    for candidate in _musart_candidates():
        try:
            _musart = ctypes.CDLL(candidate, mode=ctypes.RTLD_GLOBAL)
            return _musart
        except OSError as exc:
            errors.append(f"{candidate}: {exc}")

    joined = "; ".join(errors)
    raise RuntimeError(f"Unable to load libmusart.so for MUSA device selection: {joined}")


def _check_musa_status(status, api):
    if status != 0:
        raise RuntimeError(f"{api} failed with MUSA error code {status}")


def _musa_set_device(device_id):
    musart = _load_musart()
    func = musart.musaSetDevice
    func.argtypes = [ctypes.c_int]
    func.restype = ctypes.c_int
    _check_musa_status(func(int(device_id)), "musaSetDevice")


def _musa_get_device(default=0):
    musart = _load_musart()
    func = musart.musaGetDevice
    func.argtypes = [ctypes.POINTER(ctypes.c_int)]
    func.restype = ctypes.c_int
    device = ctypes.c_int(int(default))
    _check_musa_status(func(ctypes.byref(device)), "musaGetDevice")
    return device.value


class _System:
    @property
    def num_devices(self):
        visible = os.environ.get("MUSA_VISIBLE_DEVICES") or os.environ.get("CUDA_VISIBLE_DEVICES")
        if visible:
            return max(1, len([item for item in visible.split(",") if item.strip()]))
        return int(os.environ.get("MUSA_NUM_DEVICES", "1"))


system = _System()


class Device:
    def __init__(self, device_id=None):
        if device_id is None:
            env_device = os.environ.get("MUSA_DEVICE") or os.environ.get("LOCAL_RANK")
            if env_device is not None:
                device_id = int(env_device)
            else:
                device_id = _musa_get_device(default=0)
        self.device_id = int(device_id)

    def set_current(self):
        _musa_set_device(self.device_id)
        return self

    def create_event(self, options=None):
        return Event(enable_timing=bool((options or {}).get("enable_timing")))

    def __repr__(self):
        return f"<MUSA Device {self.device_id}>"


class Event:
    def __init__(self, enable_timing=False):
        self.enable_timing = enable_timing
        self._timestamp = None

    def record(self):
        self._timestamp = time.perf_counter()

    def sync(self):
        return None

    def __sub__(self, other):
        if self._timestamp is None or other._timestamp is None:
            return 0.0
        return (self._timestamp - other._timestamp) * 1000.0


class Stream:
    def __init__(self, handle=0):
        self.handle = int(handle)

    def record(self, event):
        event.record()

    def __int__(self):
        return self.handle


class MemoryResource:
    def allocate(self, size, stream=None):
        raise NotImplementedError

    def deallocate(self, ptr, size, stream=None):
        raise NotImplementedError


class Buffer:
    def __init__(self, ptr, size, mr):
        self._mnff = SimpleNamespace(ptr=int(ptr))
        self.handle = int(ptr)
        self.size = int(size)
        self.memory_resource = mr
        self._closed = False

    def close(self):
        if not self._closed:
            if not getattr(self, "_nvshmem_peer_alias", False):
                self.memory_resource.deallocate(self._mnff.ptr, self.size)
            self._closed = True

    def __dlpack__(self, stream=None):
        raise NotImplementedError("MUSA DLPack export is not available in the lightweight compat layer")

    def __dlpack_device__(self):
        raise NotImplementedError("MUSA DLPack export is not available in the lightweight compat layer")

    def __repr__(self):
        return f"<MUSA Buffer ptr={self._mnff.ptr} size={self.size}>"


def as_stream_handle(stream):
    if isinstance(stream, int):
        return stream
    if hasattr(stream, "handle"):
        return int(stream.handle)
    return int(stream)
