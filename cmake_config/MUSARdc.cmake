# MUSA RDC compile/link flags for targets that cannot use MUSA_SEPARABLE_COMPILATION.
if(NOT DEFINED MTSHMEM_MUSA_ARCH)
  if(CMAKE_MUSA_ARCHITECTURES)
    list(GET CMAKE_MUSA_ARCHITECTURES 0 MTSHMEM_MUSA_ARCH)
  else()
    set(MTSHMEM_MUSA_ARCH mp_31)
  endif()
endif()

function(mtshmem_enable_musa_rdc target)
  mtshmem_enable_musa_rdc_compile(${target} ${ARGN})
  mtshmem_enable_musa_rdc_link(${target})
endfunction()

function(mtshmem_enable_musa_rdc_compile target)
  set(oneValueArgs STD)
  cmake_parse_arguments(ARG "" "${oneValueArgs}" "" ${ARGN})
  if(NOT ARG_STD)
    set(ARG_STD c++17)
  endif()
  target_compile_options(${target} PRIVATE
    -x musa
    -fgpu-rdc
    --musa-path=${MUSA_HOME}
    --offload-arch=${MTSHMEM_MUSA_ARCH}
    -std=${ARG_STD}
    "SHELL:-mllvm -mtgpu-assume-nested-constant-as-global"
    "SHELL:-mllvm -misched-topdown"
  )
endfunction()

function(mtshmem_enable_musa_rdc_link target)
  target_link_options(${target} PRIVATE
    -rdc=true
    --offload-arch=${MTSHMEM_MUSA_ARCH}
  )
endfunction()
