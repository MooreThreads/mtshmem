/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2026-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef _NVSHMEM_TENSOR_H_
#define _NVSHMEM_TENSOR_H_

#include <musa_runtime.h>
#ifdef NVSHMEM_COMPLEX_SUPPORT
#include <complex.h>
#endif
#include "musa_fp16.h"
#if !defined(__MUSACC__)
typedef struct __half half;
#endif
#include "musa_bf16.h"
#include "musa_fp8.h"

#if !defined __MUSACC_RTC__
#include <stdint.h>
#include <limits.h>
#include <tuple>
#include <type_traits>
#define NVSHMEMI_TENSOR_STD std
#else
#include "musa/std/cstdint"
#include <musa/std/climits>
#include <musa/std/cstddef>
#include <musa/std/tuple>
#include <musa/std/type_traits>
#if !defined SIZE_MAX
#define SIZE_MAX (1ULL << 63)
#endif
#define NVSHMEMI_TENSOR_STD musa::std
#endif

#include "non_abi/nvshmem_build_options.h"
#include "device_host_transport/nvshmem_common_transport.h"
#include "device_host/nvshmem_types.h"
#include "device_host_transport/nvshmem_constants.h"

template <int v>
struct ConstInt : NVSHMEMI_TENSOR_STD::integral_constant<int, v> {
    __host__ __device__ constexpr operator int() const { return v; }
};

namespace nvshmemx {

template <class... Shapes>
using shape = NVSHMEMI_TENSOR_STD::tuple<Shapes...>;

template <class... Strides>
using stride = NVSHMEMI_TENSOR_STD::tuple<Strides...>;

template <class... Ts>
__host__ __device__ constexpr shape<Ts...> make_shape(Ts const&... t) {
    return {t...};
}

template <class... Ts>
__host__ __device__ constexpr stride<Ts...> make_stride(Ts const&... t) {
    return {t...};
}

template <class Shape, class Stride>
struct Layout : private NVSHMEMI_TENSOR_STD::tuple<Shape, Stride> {
    __host__ __device__ constexpr Layout(Shape const& shape = {}, Stride const& stride = {})
        : NVSHMEMI_TENSOR_STD::tuple<Shape, Stride>(shape, stride) {}

    __host__ __device__ constexpr Shape shape() const {
        return NVSHMEMI_TENSOR_STD::get<0>(
            static_cast<const NVSHMEMI_TENSOR_STD::tuple<Shape, Stride>&>(*this));
    }

    __host__ __device__ constexpr Stride stride() const {
        return NVSHMEMI_TENSOR_STD::get<1>(
            static_cast<const NVSHMEMI_TENSOR_STD::tuple<Shape, Stride>&>(*this));
    }
};

template <class Shape, class Stride>
__host__ __device__ constexpr Layout<Shape, Stride> make_layout(Shape const& shape,
                                                                Stride const& stride) {
    return Layout<Shape, Stride>(shape, stride);
}

template <typename T, class Layout>
struct Tensor {
    using value_type = T;
    using layout_type = Layout;
    T* _data;
    const Layout _layout;

    __host__ __device__ constexpr Tensor(T* data, Layout layout) : _data(data), _layout(layout) {}
    Tensor(Layout layout) : _data(NULL), _layout(layout) {}

    __host__ __device__ constexpr Layout layout() const { return _layout; }

    __host__ __device__ T* data() { return _data; }

    __host__ __device__ constexpr decltype(_layout.stride()) const stride() const {
        return _layout.stride();
    }

    __host__ __device__ constexpr decltype(_layout.shape()) const shape() const {
        return _layout.shape();
    }
};

typedef enum {
    NVLS_ONE_SHOT_PUSH_NBI = 0,
    NVLS_ONE_SHOT_PULL_NBI = 1,
    NVLS_TWO_SHOT_PUSH_NBI = 2,
    NVLS_TWO_SHOT_PULL_NBI = 3,
    NVSHMEMI_TILE_ALGO_SENTINEL = INT_MAX
} tile_coll_algo_t;

}  // namespace nvshmemx

#undef NVSHMEMI_TENSOR_STD

#endif /* _NVSHMEM_TENSOR_H_ */
