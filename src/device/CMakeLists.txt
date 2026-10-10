# Allow users to set the MUSA toolkit through the env.
cmake_minimum_required(VERSION 3.19)

include(CMakePackageConfigHelpers)

set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/../.." CACHE PATH "..." FORCE)

if (DEFINED ENV{NVSHMEM_DEVICELIB_MUSA_HOME})
  set(NVSHMEM_DEVICELIB_MUSA_HOME_DEFAULT $ENV{NVSHMEM_DEVICELIB_MUSA_HOME})
elseif(DEFINED ENV{MUSA_HOME})
  set(NVSHMEM_DEVICELIB_MUSA_HOME_DEFAULT $ENV{MUSA_HOME})
else()
  set(NVSHMEM_DEVICELIB_MUSA_HOME_DEFAULT "/usr/local/musa")
endif()

set(NVSHMEM_DEVICELIB_MUSA_HOME ${NVSHMEM_DEVICELIB_MUSA_HOME_DEFAULT} CACHE PATH "path to MUSA installation")
set(MUSA_HOME ${NVSHMEM_DEVICELIB_MUSA_HOME} CACHE PATH "path to MUSA installation")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake_config")
include(MUSARdc)

if (NOT DEFINED CMAKE_MUSA_ARCHITECTURES)
  set(CMAKE_MUSA_ARCHITECTURES_UNDEFINED 1)
endif()

if (NOT DEFINED MUSA_ARCHITECTURES)
  set(MUSA_ARCHITECTURES_UNDEFINED 1)
endif()

if (NVSHMEM_DEBUG)
	message(STATUS "Setting build type to Debug as requested by the environment.")
  set(CMAKE_BUILD_TYPE "debug" CACHE STRING "Choose the type of build." FORCE)
endif()

if(NOT MUSAToolkit_Root AND NOT CMAKE_MUSA_COMPILER)
  message(STATUS "MUSA_DEVICELIB_HOME: ${NVSHMEM_DEVICELIB_MUSA_HOME}")
  set(MUSAToolkit_Root ${NVSHMEM_DEVICELIB_MUSA_HOME} CACHE PATH "Root of Musa Toolkit." FORCE)
  set(CMAKE_MUSA_COMPILER "${NVSHMEM_DEVICELIB_MUSA_HOME}/bin/mcc" CACHE PATH "Root of Musa Toolkit." FORCE)
endif()

project(
  NVSHMEM_DEVICE
  LANGUAGES CXX C
  VERSION ${PROJECT_VERSION}
)

find_package(MUSAToolkit)

if(NOT TARGET MUSA::musart)
  add_library(MUSA::musa_driver UNKNOWN IMPORTED)
  target_include_directories(MUSA::musa_driver SYSTEM INTERFACE "${MUSA_HOME}/include")
  set_property(TARGET MUSA::musa_driver PROPERTY IMPORTED_LOCATION "${MUSA_HOME}/lib/stubs/libmusa.so")
  add_library(MUSA::musart UNKNOWN IMPORTED)
  target_include_directories(MUSA::musart SYSTEM INTERFACE "${MUSA_HOME}/include")
  set_property(TARGET MUSA::musart PROPERTY IMPORTED_LOCATION "${MUSA_HOME}/lib/libmusart.so")
  target_link_libraries(MUSA::musart INTERFACE MUSA::musa_driver)
endif()

if(DEFINED CMAKE_MUSA_ARCHITECTURES_UNDEFINED)
  if(NOT DEFINED MUSA_ARCHITECTURES_UNDEFINED)
    set(CMAKE_MUSA_ARCHITECTURES ${MUSA_ARCHITECTURES} CACHE STRING "MUSA ARCHITECTURES" FORCE)
  else()
    if(MUSAToolkit_VERSION_MAJOR LESS 11)
      set(CMAKE_MUSA_ARCHITECTURES 70 CACHE STRING "MUSA ARCHITECTURES" FORCE)
    elseif(MUSAToolkit_VERSION_MAJOR EQUAL 11 AND MUSAToolkit_VERSION_MINOR LESS 8)
      set(CMAKE_MUSA_ARCHITECTURES 70 80 CACHE STRING "MUSA ARCHITECTURES" FORCE)
    elseif(MUSAToolkit_VERSION_MAJOR EQUAL 12 AND MUSAToolkit_VERSION_MINOR LESS 7)
      set(CMAKE_MUSA_ARCHITECTURES 70 80 90 CACHE STRING "MUSA ARCHITECTURES" FORCE)
    else()
      set(CMAKE_MUSA_ARCHITECTURES 70 80 90 100 CACHE STRING "MUSA ARCHITECTURES" FORCE)
    endif()
  endif()
endif()
foreach(ARCH ${CMAKE_MUSA_ARCHITECTURES})
  set(NVCC_GENCODE "${NVCC_GENCODE}" "-gencode=arch=compute_${ARCH},code=sm_${ARCH};-gencode=arch=compute_${ARCH},code=compute_${ARCH}")
endforeach()
mark_as_advanced(NVCC_GENCODE CMAKE_MUSA_ARCHITECTURES_UNDEFINED MUSA_ARCHITECTURES_UNDEFINED)
message(STATUS "CMAKE_MUSA_ARCHITECTURES: ${CMAKE_MUSA_ARCHITECTURES}")
message(STATUS "CMAKE_MUSA_COMPILER: ${CMAKE_MUSA_COMPILER}")
message(STATUS "NVSHMEM_PREFIX: ${NVSHMEM_PREFIX}")
message(STATUS "NVSHMEM_DEBUG: ${NVSHMEM_DEBUG}")

# MUSA's device-side tuple/type-traits implementation requires C++17.
set(LIB_CXX_STANDARD 17)

install(
  EXPORT NVSHMEMDeviceTargets
  NAMESPACE nvshmem::
  DESTINATION lib/cmake/nvshmem/
)

add_library(
  nvshmem_device STATIC
)
target_compile_features(nvshmem_device PUBLIC cxx_std_17)

install(
	TARGETS nvshmem_device
  EXPORT NVSHMEMDeviceTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES
  DESTINATION include
  PUBLIC_HEADER DESTINATION include
)

set_target_properties(nvshmem_device
                      PROPERTIES POSITION_INDEPENDENT_CODE ON
                      CXX_STANDARD_REQUIRED ON
                      CXX_STANDARD "${LIB_CXX_STANDARD}"
                      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/../lib"
                      ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/../lib"
		      VERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}
		      SOVERSION ${PROJECT_VERSION_MAJOR}
)

macro(nvshmem_library_set_base_config LIBNAME)
  target_compile_definitions(${LIBNAME}
    PRIVATE $<$<CONFIG:Debug>:_NVSHMEM_DEBUG;NVSHMEM_IBGDA_DEBUG>
    $<IF:$<STREQUAL:"${CMAKE_HOST_SYSTEM_PROCESSOR}","x86_64">,NVSHMEM_X86_64,>
    $<IF:$<STREQUAL:"${CMAKE_HOST_SYSTEM_PROCESSOR}","ppc64le">,__STDC_LIMIT_MACROS;__STDC_CONSTANT_MACROS;NVSHMEM_PPC64LE,>
    $<IF:$<STREQUAL:"${CMAKE_HOST_SYSTEM_PROCESSOR}","aarch64">,NVSHMEM_AARCH64,>
    PUBLIC $<$<COMPILE_LANGUAGE:MUSA>:__STDC_LIMIT_MACROS;__STDC_CONSTANT_MACROS>
  )

  target_compile_options(${LIBNAME}
    INTERFACE $<$<AND:$<COMPILE_LANGUAGE:MUSA>,$<BOOL:${NVSHMEM_VERBOSE}>>:-Xptxas -v>
    PRIVATE $<IF:$<CONFIG:Debug>,-O0;-g;,-O3>
    $<$<AND:$<BOOL:${NVSHMEM_VERBOSE}>,$<COMPILE_LANGUAGE:MUSA>>:-Xptxas -v>
    $<IF:$<AND:$<COMPILE_LANGUAGE:MUSA>,$<CONFIG:Debug>>,-O0;-g;-G;,-O3>
    $<IF:$<STREQUAL:${CMAKE_HOST_SYSTEM_PROCESSOR},"x86_64">,-msse,>
    $<$<AND:$<COMPILE_LANGUAGE:MUSA>,$<BOOL:${NVCC_THREADS}>>:-t4>
  )

  if(NVSHMEM_DEVEL)
    target_compile_options(
      ${LIBNAME}
      PRIVATE $<$<COMPILE_LANGUAGE:MUSA>:-Werror
              all-warnings>
              $<$<COMPILE_LANGUAGE:CXX>:-Werror
              -Wall
              -Wextra
              -Wno-unused-function
              -Wno-unused-parameter
              -Wno-missing-field-initializers>
    )
  endif()
endmacro()

set(NVSHMEM_DEVICE_SOURCES
    init/init_device.cu
    launch/collective_launch.cpp
)

target_include_directories(
  nvshmem_device
  PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../include
  INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/../include>
            $<INSTALL_INTERFACE:include>
)

if(NVSHMEM_ENABLE_ALL_DEVICE_INLINING)
  configure_file(../include/non_abi/device/pt-to-pt/transfer_device.cuh.in ${CMAKE_CURRENT_SOURCE_DIR}/../include/non_abi/device/pt-to-pt/transfer_device.cuh COPYONLY)
else()
  set(NVSHMEM_DEVICE_SOURCES
      ${NVSHMEM_DEVICE_SOURCES}
      comm/transfer_device.cu
  )
  configure_file(../include/non_abi/device/pt-to-pt/transfer_device.cuh.in ${CMAKE_CURRENT_SOURCE_DIR}/comm/transfer_device.cu COPYONLY)
endif()

target_link_libraries(nvshmem_device PRIVATE MUSA::musart)

if(NVSHMEM_USE_NCCL)
  target_include_directories(nvshmem_device PRIVATE ${NCCL_INCLUDE})
endif()

nvshmem_library_set_base_config(nvshmem_device)
mtshmem_enable_musa_rdc(nvshmem_device)

foreach(file ${NVSHMEM_DEVICE_SOURCES})
  set_source_files_properties(${file} PROPERTIES LANGUAGE CXX)
endforeach()
target_sources(nvshmem_device PRIVATE ${NVSHMEM_DEVICE_SOURCES} ${NVSHMEM_DEVICE_SOURCES_NOMAXREGCOUNT})
