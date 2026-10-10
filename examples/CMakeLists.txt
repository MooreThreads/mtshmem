cmake_minimum_required(VERSION 3.19)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake_config")
include(MUSARdc)

get_directory_property(SubBuild PARENT_DIRECTORY)

if (DEFINED ENV{NVSHMEM_EXAMPLES_INSTALL})
  set(NVSHMEM_EXAMPLES_INSTALL_PREFIX $ENV{NVSHMEM_EXAMPLES_INSTALL})
elseif(NOT SubBuild)
  set(NVSHMEM_EXAMPLES_INSTALL_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/examples_install")
endif()

if(NOT SubBuild)
  if (DEFINED ENV{NVSHMEM_PREFIX})
    set(NVSHMEM_PREFIX_DEFAULT $ENV{NVSHMEM_PREFIX})
  else()
    set(NVSHMEM_PREFIX_DEFAULT "/usr/local/nvshmem")
  endif()

  if (DEFINED ENV{NVSHMEM_MPI_SUPPORT})
    set(NVSHMEM_MPI_SUPPORT_DEFAULT $ENV{NVSHMEM_MPI_SUPPORT})
  else()
    set(NVSHMEM_MPI_SUPPORT_DEFAULT ON)
  endif()

  if (DEFINED ENV{MPI_HOME})
    set(MPI_HOME_DEFAULT $ENV{MPI_HOME})
  else()
    set(MPI_HOME_DEFAULT "/usr/local/ompi")
  endif()

  if (DEFINED ENV{MUSA_HOME})
    set(MUSA_HOME_DEFAULT $ENV{MUSA_HOME})
  else()
    set(MUSA_HOME_DEFAULT "/usr/local/musa")
  endif()

  option(NVSHMEM_DEBUG "Toggles NVSHMEM debug compilation settings" $ENV{NVSHMEM_DEBUG})
  option(NVSHMEM_DEVEL "Toggles NVSHMEM devel compilation settings" $ENV{NVSHMEM_DEVEL})
  option(NVSHMEM_MPI_SUPPORT "Enable compilation of the MPI bootstrap and MPI-specific code" ${NVSHMEM_MPI_SUPPORT_DEFAULT})
  option(NVSHMEM_SHMEM_SUPPORT "Enable Compilation of the SHMEM bootstrap and SHMEM specific code" $ENV{NVSHMEM_SHMEM_SUPPORT})
  option(NVSHMEM_TEST_STATIC_LIB "Force tests to link only against the combined nvshmem.a binary" $ENV{NVSHMEM_TEST_STATIC_LIB})
  option(NVSHMEM_VERBOSE "Enable the ptxas verbose compilation option" $ENV{NVSHMEM_VERBOSE})
  set(MUSA_HOME ${MUSA_HOME_DEFAULT} CACHE PATH "path to MUSA installation")
  set(MPI_HOME ${MPI_HOME_DEFAULT} CACHE PATH "path to MPI installation")
  set(NVSHMEM_PREFIX ${NVSHMEM_PREFIX_DEFAULT} CACHE PATH "path to NVSHMEM install directory.")
  set(SHMEM_HOME ${MPI_HOME} CACHE PATH "path to SHMEM installation")

  # Allow users to set the MUSA toolkit through the env.
  if(NOT MUSAToolkit_Root AND NOT CMAKE_MUSA_COMPILER)
  message(STATUS "MUSA_HOME: ${MUSA_HOME}")
  set(MUSAToolkit_Root ${MUSA_HOME} CACHE PATH "Root of Musa Toolkit." FORCE)
  set(CMAKE_MUSA_COMPILER "${MUSA_HOME}/bin/mcc" CACHE PATH "Root of Musa Toolkit." FORCE)
  endif()

  if (NOT DEFINED CMAKE_MUSA_ARCHITECTURES)
    set(CMAKE_MUSA_ARCHITECTURES_UNDEFINED 1)
  endif()

  if (NOT DEFINED MUSA_ARCHITECTURES)
    set(MUSA_ARCHITECTURES_UNDEFINED 1)
  endif()

  PROJECT(NVSHMEMExamples VERSION 1.0.0
          LANGUAGES CXX)

  find_package(MUSAToolkit)

  if(DEFINED CMAKE_MUSA_ARCHITECTURES_UNDEFINED)
    if(NOT DEFINED MUSA_ARCHITECTURES_UNDEFINED)
      set(CMAKE_MUSA_ARCHITECTURES ${MUSA_ARCHITECTURES} CACHE STRING "MUSA ARCHITECTURES" FORCE)
    else()
      if(MUSAToolkit_VERSION_MAJOR LESS 11)
        set(CMAKE_MUSA_ARCHITECTURES 70 CACHE STRING "MUSA ARCHITECTURES" FORCE)
      elseif(MUSAToolkit_VERSION_MAJOR EQUAL 11 AND MUSAToolkit_VERSION_MINOR LESS 8)
        set(CMAKE_MUSA_ARCHITECTURES 70 80 CACHE STRING "MUSA ARCHITECTURES" FORCE)
      else()
        set(CMAKE_MUSA_ARCHITECTURES 70 80 90 CACHE STRING "MUSA ARCHITECTURES" FORCE)
      endif()
    endif()
  endif()
  foreach(ARCH ${CMAKE_MUSA_ARCHITECTURES})
  set(NVCC_GENCODE "${NVCC_GENCODE}-gencode=arch=compute_${ARCH},code=sm_${ARCH};-gencode=arch=compute_${ARCH},code=compute_${ARCH};")
  endforeach()
  mark_as_advanced(NVCC_GENCODE CMAKE_MUSA_ARCHITECTURES_UNDEFINED MUSA_ARCHITECTURES_UNDEFINED)

  include(CheckCompilerFlag)
  check_compiler_flag(CXX "-t4" NVCC_THREADS)

  find_package(NVSHMEM REQUIRED HINTS ${NVSHMEM_PREFIX}/lib/cmake/nvshmem)
  add_library(nvshmem ALIAS nvshmem::nvshmem)
  add_library(nvshmem_host ALIAS nvshmem::nvshmem_host)
  add_library(nvshmem_shared ALIAS nvshmem::nvshmem_host)
  add_library(nvshmem_device ALIAS nvshmem::nvshmem_device)

  if(NVSHMEM_MPI_SUPPORT)
    find_package(MPI REQUIRED)
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
endif()

add_library(nvshmem_example_helper INTERFACE)
target_link_libraries(nvshmem_example_helper INTERFACE MUSA::musart MUSA::musa_driver)
target_include_directories(nvshmem_example_helper INTERFACE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_BINARY_DIR}/src/include
)
target_compile_features(nvshmem_example_helper INTERFACE cxx_std_17)

if(NVSHMEM_SHMEM_SUPPORT)
  target_link_libraries(nvshmem_example_helper INTERFACE shmem)
  target_compile_definitions(nvshmem_example_helper INTERFACE NVSHMEMTEST_SHMEM_SUPPORT)
endif()
if(NVSHMEM_MPI_SUPPORT)
  target_link_libraries(nvshmem_example_helper INTERFACE MPI::MPI_CXX)
  target_compile_definitions(nvshmem_example_helper INTERFACE NVSHMEMTEST_MPI_SUPPORT)
endif()

set(EXAMPLES
  collective-launch.cu
  on-stream.cu
  wait-signal-on-stream.cu
  graph-barrier-visibility.cu
  thread-group.cu
  put-block.cu
  buffer-register.cu
  team-split.cu
  team-flex-init.cu
  info-query.cu
  dev-guide-ring.cu
  hello.cpp
  hello-error.cpp
  hello-before-init.cu
  host-put-get.cu
  ring-bcast.cu
  ring-reduce.cu
  moe_shuffle.cu
  alltoall.cu
  )

if(NVSHMEM_BUILD_MUTLASS_EXAMPLES)
  message(WARNING "NVSHMEM_BUILD_MUTLASS_EXAMPLES is enabled, but MUTLASS example sources are not available yet.")
endif()

if(NVSHMEM_MPI_SUPPORT)
  LIST(APPEND EXAMPLES
    mpi-based-init.cu
    uid-based-init.cu
    dev-guide-ring-mpi.cu
    p2p-vismask-mpi.cu
    ibgda-atomic-add-mpi.cu
  )
endif()

foreach(example ${EXAMPLES})
  get_filename_component(NAME_ ${example} NAME_WE)

  set_source_files_properties(${example} PROPERTIES LANGUAGE CXX)
  add_executable(${NAME_} ${example})
  target_link_libraries(${NAME_} PRIVATE nvshmem_example_helper)
  target_link_libraries(${NAME_} PRIVATE nvshmem_host nvshmem_device)
  mtshmem_enable_musa_rdc(${NAME_})

  set_target_properties(${NAME_} PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME "${NAME_}"
    INSTALL_RPATH "$ORIGIN/../../lib"
    BUILD_WITH_INSTALL_RPATH TRUE
  )
  target_compile_options(${NAME_}
    PRIVATE $<$<CONFIG:Debug>:-O0;-g>
    $<$<AND:$<BOOL:${NVSHMEM_VERBOSE}>,$<COMPILE_LANGUAGE:MUSA>>:-Xptxas -v>
    $<$<AND:$<COMPILE_LANGUAGE:MUSA>,$<CONFIG:Debug>>:-O0;-g;-G>
    $<$<AND:$<COMPILE_LANGUAGE:MUSA>,$<BOOL:${NVCC_THREADS}>>:-t4>
  )
  install(TARGETS ${NAME_} RUNTIME DESTINATION "${NVSHMEM_EXAMPLES_INSTALL_PREFIX}")
  if(NVSHMEM_EXAMPLES_RELEASE_PREFIX)
    install(TARGETS ${NAME_} RUNTIME DESTINATION "${NVSHMEM_EXAMPLES_RELEASE_PREFIX}")
  endif()
endforeach()
