cmake_minimum_required(VERSION 3.19)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake_config")

include(NVSHMEMEnv)
include(MUSARdc)
include(CMakePackageConfigHelpers)

if(NVSHMEM_IBGDA_SUPPORT AND NOT NVSHMEM_ENABLE_ALL_DEVICE_INLINING)
  message(FATAL_ERROR
    "MTSHMEM IBGDA requires NVSHMEM_ENABLE_ALL_DEVICE_INLINING=ON because "
    "out-of-line device calls can trigger cluster write synchronization failures")
endif()

enable_testing()

option(BUILD_NVSHMEM4PY "Build nvshmem4py Python bindings" OFF)

if (NVSHMEM_DEBUG)
	message(STATUS "Setting build type to Debug as requested by the environment.")
  set(CMAKE_BUILD_TYPE "debug" CACHE STRING "Choose the type of build." FORCE)
endif()

set(default_build_type "release")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to '${default_build_type}' as none was specified.")
  set(CMAKE_BUILD_TYPE "${default_build_type}" CACHE STRING "Choose the type of build." FORCE)
endif()

if (NVSHMEM_COVERAGE_TEST)
  set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-fprofile-arcs -ftest-coverage -fprofile-instr-generate -fcoverage-mapping")
  message(STATUS "NVSHMEM_COVERAGE_TEST: ${NVSHMEM_COVERAGE_TEST}")
endif()

set(MUSA_MCC_FLAGS -x musa -fgpu-rdc --musa-path=${MUSA_HOME})
if (DEFINED ENV{MCC_EXTRA_ARGS})
  foreach(arg  $ENV{MCC_EXTRA_ARGS})
    message("MCC_EXTRA_ARGS: ${arg}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${arg}")
    LIST(APPEND MUSA_MCC_FLAGS ${arg})
  endforeach()
endif()
message("CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")

# Set the possible values of build type
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "debug" "release"
             "MinSizeRel" "RelWithDebInfo")

## MUSA Selection Start

# Allow users to set the MUSA toolkit through the env.
if(NOT MUSAToolkit_Root AND NOT CMAKE_MUSA_COMPILER)
  message(STATUS "MUSA_HOME: ${MUSA_HOME}")
  set(MUSAToolkit_Root ${MUSA_HOME} CACHE PATH "Root of Musa Toolkit." FORCE)
  set(CMAKE_CXX_COMPILER "${MUSA_HOME}/bin/mcc" CACHE PATH "Root of Musa Toolkit." FORCE)
  set(MUSA_ARCHITECTURES mp_31)
endif()

# Save value of CMAKE_MUSA_ARCHITECTURES before calling project()
# This is to solve a chicken-egg problem. It seems FIND_MUSA doesn't
# work without project(), but project() overwrites CMAKE_MUSA_ARCHITECTURES.
# We need to know the version of the MUSA Toolkit before we can set the project
# defaults. So this lets us know beforehand if the user has specified a preference.
if (NOT DEFINED CMAKE_MUSA_ARCHITECTURES)
  set(CMAKE_MUSA_ARCHITECTURES_UNDEFINED 1)
endif()

if (NOT DEFINED MUSA_ARCHITECTURES)
  set(MUSA_ARCHITECTURES_UNDEFINED 1)
endif()

project(
  NVSHMEM
  LANGUAGES CXX C
  VERSION 3.7.0.0
)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set_property(CACHE CMAKE_INSTALL_PREFIX PROPERTY VALUE "${NVSHMEM_PREFIX}")
endif()

# find_package(MUSAToolkit)
add_library(MUSA::musa_driver UNKNOWN IMPORTED)
target_include_directories(MUSA::musa_driver SYSTEM INTERFACE "${MUSA_HOME}/include")
set_property(TARGET MUSA::musa_driver PROPERTY IMPORTED_LOCATION "${MUSA_HOME}/lib/stubs/libmusa.so")
add_library(MUSA::musart UNKNOWN IMPORTED)
target_include_directories(MUSA::musart SYSTEM INTERFACE "${MUSA_HOME}/include")
set_property(TARGET MUSA::musart PROPERTY IMPORTED_LOCATION "${MUSA_HOME}/lib/libmusart.so")
target_link_libraries(MUSA::musart INTERFACE MUSA::musa_driver)

if (NOT DEFINED MUSAToolkit_VERSION_MAJOR)
  set(MUSAToolkit_VERSION_MAJOR 4)
endif()

if(DEFINED CMAKE_MUSA_ARCHITECTURES_UNDEFINED)
  if(NOT DEFINED MUSA_ARCHITECTURES_UNDEFINED)
    set(CMAKE_MUSA_ARCHITECTURES ${MUSA_ARCHITECTURES} CACHE STRING "MUSA ARCHITECTURES" FORCE)
  else()
    if(MUSAToolkit_VERSION_MAJOR LESS 11)
      set(CMAKE_MUSA_ARCHITECTURES "70" CACHE STRING "MUSA ARCHITECTURES" FORCE)
    elseif(MUSAToolkit_VERSION_MAJOR EQUAL 11 AND MUSAToolkit_VERSION_MINOR LESS 8)
      set(CMAKE_MUSA_ARCHITECTURES "70;80" CACHE STRING "MUSA ARCHITECTURES" FORCE)
    else()
      set(CMAKE_MUSA_ARCHITECTURES "70;80;90" CACHE STRING "MUSA ARCHITECTURES" FORCE)
    endif()
  endif()
endif()
foreach(ARCH ${CMAKE_MUSA_ARCHITECTURES})
#   set(NVCC_GENCODE "${NVCC_GENCODE}" "-gencode=arch=compute_${ARCH},code=sm_${ARCH};-gencode=arch=compute_${ARCH},code=compute_${ARCH}")
endforeach()
mark_as_advanced(NVCC_GENCODE CMAKE_MUSA_ARCHITECTURES_UNDEFINED MUSA_ARCHITECTURES_UNDEFINED)

message(STATUS "CMAKE_MUSA_ARCHITECTURES: ${CMAKE_MUSA_ARCHITECTURES}")

## MUSA Selection End

## Find Packages Start

if(NVSHMEM_UCX_SUPPORT)
  find_package(UCX PATHS ${UCX_HOME} REQUIRED)
endif()

if(NVSHMEM_MPI_SUPPORT)
  find_package(MPI REQUIRED)
endif()

# Find the MCCL compatibility header.
if(NVSHMEM_USE_NCCL)
  find_path(
    NCCL_INCLUDE mccl.h
    HINTS ${CMAKE_SOURCE_DIR} ${MCCL_HOME}
    PATH_SUFFIXES include_nccl include lib64
  )
endif()

if(NVSHMEM_USE_GDRCOPY)
  find_path(
    GDRCOPY_INCLUDE mtgdrapi.h
    PATHS /usr/local/gdrcopy /usr/local/gdrdrv ${CMAKE_SOURCE_DIR}
    HINTS ${CMAKE_SOURCE_DIR} /usr/local/gdrcopy /usr/local/gdrdrv ${GDRCOPY_HOME}
    PATH_SUFFIXES include_gdrcopy include
  )
endif()

if(NVSHMEM_SHMEM_SUPPORT)
  find_library(
    SHMEM_LIB
    NAMES oshmem
    HINTS ${SHMEM_HOME}
    PATH_SUFFIXES lib lib64)
  find_path(SHMEM_INCLUDE NAME shmem.h HINTS ${SHMEM_HOME}
            PATH_SUFFIXES include
  )
  add_library(shmem IMPORTED INTERFACE)
  target_link_libraries(shmem INTERFACE ${SHMEM_LIB})
  target_include_directories(shmem INTERFACE ${SHMEM_INCLUDE})
  if(NVSHMEM_MPI_SUPPORT)
    separate_arguments(SHMEM_C_LINK_FLAGS NATIVE_COMMAND "${MPI_C_LINK_FLAGS}")
    target_link_options(shmem INTERFACE ${SHMEM_C_LINK_FLAGS})
    target_compile_definitions(shmem INTERFACE ${MPI_C_COMPILE_DEFINITIONS})
    target_compile_options(shmem INTERFACE ${MPI_C_COMPILE_OPTIONS})
  endif()
endif()

## Find Packages End

# set these flags to add a RUNPATH entry to the libraries that points at the lib dir in a portable way.
set(CMAKE_SKIP_BUILD_RPATH  FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
set(CMAKE_INSTALL_RPATH "$\{ORIGIN\}")
set(CMAKE_EXE_LINKER_FLAGS "-Wl,--enable-new-dtags")

cmake_policy(SET CMP0105 NEW)
set(CMAKE_MUSA_DEVICE_COMPILER_WRAPPER_FLAG "")

configure_file(License.txt License.txt COPYONLY)

set(INCLUDE_INSTALL_DIR include/)
set(LIB_INSTALL_DIR lib/)
set(BIN_INSTALL_DIR bin/)

configure_package_config_file(
  ${CMAKE_SOURCE_DIR}/cmake_config/NVSHMEMConfig.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/NVSHMEMConfig.cmake
  INSTALL_DESTINATION ${LIB_INSTALL_DIR}/cmake/nvshmem
  PATH_VARS INCLUDE_INSTALL_DIR LIB_INSTALL_DIR BIN_INSTALL_DIR)

write_basic_package_version_file(
  NVSHMEMVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY AnyNewerVersion)

add_subdirectory(src)

if(BUILD_NVSHMEM4PY)
  add_subdirectory(nvshmem4py)
endif()
