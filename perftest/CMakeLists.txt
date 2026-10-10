cmake_minimum_required(VERSION 3.19)
set(CMAKE_MUSA_SEPARABLE_COMPILATION ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake_config")
include(MUSARdc)

set(NVSHMEM_PERFTEST_TLD ${CMAKE_CURRENT_SOURCE_DIR})

get_directory_property(SubBuild PARENT_DIRECTORY)

if (DEFINED ENV{NVSHMEM_PERFTEST_INSTALL})
  set(NVSHMEM_PERFTEST_INSTALL_PREFIX $ENV{NVSHMEM_PERFTEST_INSTALL})
elseif(NOT SubBuild)
  set(NVSHMEM_PERFTEST_INSTALL_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/perftest_install")
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

  option(NVSHMEM_BUILD_BITCODE_LIBRARY "Build the nvshmem_device bitcode library and mubin perftests" $ENV{NVSHMEM_BUILD_BITCODE_LIBRARY})
  option(NVSHMEM_DEBUG "Toggles NVSHMEM debug compilation settings" $ENV{NVSHMEM_DEBUG})
  option(NVSHMEM_DEVEL "Toggles NVSHMEM devel compilation settings" $ENV{NVSHMEM_DEVEL})
  option(NVSHMEM_MPI_SUPPORT "Enable compilation of the MPI bootstrap and MPI-specific code" ${NVSHMEM_MPI_SUPPORT_DEFAULT})
  option(NVSHMEM_SHMEM_SUPPORT "Enable Compilation of the SHMEM bootstrap and SHMEM specific code" $ENV{NVSHMEM_SHMEM_SUPPORT})
  option(NVSHMEM_TEST_STATIC_LIB "Force tests to link only against the combined nvshmem.a binary" $ENV{NVSHMEM_TEST_STATIC_LIB})
  option(NVSHMEM_VERBOSE "Enable the ptxas verbose compilation option" $ENV{NVSHMEM_VERBOSE})
  set(NVSHMEM_CLANG_DIR "${MUSA_HOME_DEFAULT}/bin" CACHE PATH "path to LLVM/clang for bitcode (default MUSA bin)")
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

  PROJECT(NVSHMEMPerftest VERSION 1.0.0
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

  # MUSA arch for bitcode/mubin (e.g. mp_31); CACHE so subdirs (device/pt-to-pt, coll) see it in macro
  if(CMAKE_MUSA_ARCHITECTURES)
    list(GET CMAKE_MUSA_ARCHITECTURES 0 MUSA_BITCODE_ARCH)
  else()
    set(MUSA_BITCODE_ARCH "mp_31")
  endif()
  set(MUSA_BITCODE_ARCH "${MUSA_BITCODE_ARCH}" CACHE STRING "MUSA arch for bitcode/mubin (e.g. mp_31)")

  include(CheckCompilerFlag)
  check_compiler_flag(CXX "-t4" NVCC_THREADS)

  find_package(NVSHMEM REQUIRED HINTS ${NVSHMEM_PREFIX}/lib/cmake/nvshmem)
  add_library(nvshmem ALIAS nvshmem::nvshmem)
  add_library(nvshmem_host ALIAS nvshmem::nvshmem_host)
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

add_subdirectory(common)

if(NOT SubBuild)
  file(MAKE_DIRECTORY ${NVSHMEM_PERFTEST_TLD}/common/include/non_abi/device/pt-to-pt)
  configure_file(${NVSHMEM_PERFTEST_TLD}/../src/include/non_abi/device/pt-to-pt/transfer_device.cuh.in
    ${NVSHMEM_PERFTEST_TLD}/common/include/non_abi/device/pt-to-pt/transfer_device.cuh COPYONLY)
endif()

set(MTSHMEM_PERFTEST_INCLUDES
  ${NVSHMEM_PERFTEST_TLD}/common
  ${NVSHMEM_PERFTEST_TLD}/common/include
  ${NVSHMEM_PERFTEST_TLD}/../src/include
  ${CMAKE_BINARY_DIR}/src/include
)

macro(nvshmem_add_perftest_prefix SOURCE PREFIX)
  get_filename_component(NAME_ ${SOURCE} NAME_WE)
  get_filename_component(DIR_ ${SOURCE} ABSOLUTE)
  string(REPLACE ${NVSHMEM_PERFTEST_TLD} "" DIR ${DIR_})
  string(REPLACE ${SOURCE} "" DIR ${DIR})
  set(NAME "${PREFIX}${NAME_}")
  set_source_files_properties(${SOURCE} PROPERTIES LANGUAGE CXX)
  add_executable(${NAME} ${SOURCE})
  target_include_directories(${NAME} PRIVATE ${MTSHMEM_PERFTEST_INCLUDES})
  target_link_libraries(${NAME} PRIVATE nvshmem_perftest_helper)

  if(SOURCE MATCHES "\\.cpp$")
    target_link_libraries(${NAME} PRIVATE nvshmem)
  else()
    target_link_libraries(${NAME} PRIVATE nvshmem_host nvshmem_device nvshmem_perftest_utils)
    mtshmem_enable_musa_rdc(${NAME})
  endif()

  set_target_properties(${NAME} PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME "${NAME_}"
    INSTALL_RPATH "$ORIGIN/../../../../lib"
    BUILD_WITH_INSTALL_RPATH TRUE
  )
  target_compile_options(${NAME}
    PRIVATE $<$<CONFIG:Debug>:-O0;-g>
    $<$<AND:$<BOOL:${NVSHMEM_VERBOSE}>,$<COMPILE_LANGUAGE:MUSA>>:-Xptxas -v>
    $<$<AND:$<COMPILE_LANGUAGE:MUSA>,$<CONFIG:Debug>>:-O0;-g;-G>
    $<$<AND:$<COMPILE_LANGUAGE:MUSA>,$<BOOL:${NVCC_THREADS}>>:-t4>
  )
  target_link_options(${NAME} PRIVATE -ldl)

  install(TARGETS ${NAME} RUNTIME DESTINATION "${NVSHMEM_PERFTEST_INSTALL_PREFIX}/${DIR}")
  if(NVSHMEM_PERFTEST_RELEASE_PREFIX)
    install(TARGETS ${NAME} RUNTIME DESTINATION "${NVSHMEM_PERFTEST_RELEASE_PREFIX}/${DIR}")
  endif()

  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${NAME_}.args")
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/${NAME_}.args DESTINATION ${NVSHMEM_PERFTEST_INSTALL_PREFIX}/${DIR})
    if(NVSHMEM_PERFTEST_RELEASE_PREFIX)
      install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/${NAME_}.args DESTINATION ${NVSHMEM_PERFTEST_RELEASE_PREFIX}/${DIR})
    endif()
  endif()
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${NAME_}.env")
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/${NAME_}.env DESTINATION ${NVSHMEM_PERFTEST_INSTALL_PREFIX}/${DIR})
    if(NVSHMEM_PERFTEST_RELEASE_PREFIX)
      install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/${NAME_}.env DESTINATION ${NVSHMEM_PERFTEST_RELEASE_PREFIX}/${DIR})
    endif()
  endif()

endmacro()

if(NVSHMEM_BUILD_BITCODE_LIBRARY)
  macro(nvshmem_add_mubin_perftest SOURCE)
    nvshmem_add_mubin_perftest_prefix(${SOURCE} ${NVSHMEM_TEST_PREFIX})
  endmacro()
endif()

macro(nvshmem_add_mubin_perftest_prefix SOURCE PREFIX)
  get_filename_component(NAME_ ${SOURCE} NAME_WE)
  get_filename_component(DIR_ ${SOURCE} ABSOLUTE)
  string(REPLACE ${NVSHMEM_PERFTEST_TLD} "" DIR ${DIR_})
  string(REPLACE ${SOURCE} "" DIR ${DIR})
  set(MUBIN_UNLINKED_NAME "${NAME_}_UNLINKED.mubin")
  set(MUBIN_NAME "${NAME_}.mubin")
  set(INCLUDE_DIRECTORIES "-I${NVSHMEM_PERFTEST_TLD}/common" "-I${NVSHMEM_PERFTEST_TLD}/common/include" "-I${NVSHMEM_PERFTEST_TLD}/../src/include/" "-I${NVSHMEM_PREFIX}/include")
  if(SubBuild)
    list(APPEND INCLUDE_DIRECTORIES "-I${CMAKE_BINARY_DIR}/src/llvm_lib")
  endif()
  if(NOT MUSA_BITCODE_ARCH)
    if(CMAKE_MUSA_ARCHITECTURES)
      list(GET CMAKE_MUSA_ARCHITECTURES 0 MUSA_BITCODE_ARCH)
    else()
      set(MUSA_BITCODE_ARCH "mp_31")
    endif()
  endif()
  # MUSA does not provide ptxas/nvlink; use llc -filetype=obj and use .o as .mubin (see MUSA docs for production binary format).
  if (NOT SubBuild)
    set(BITCODE_LIB_PATH ${NVSHMEM_PREFIX}/lib/libnvshmem_device.bc)
    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${MUBIN_NAME}
                      COMMAND ${MUSA_HOME}/bin/clang -c -emit-llvm -std=c++17 ${MUSA_MCC_FLAGS} --cuda-device-only
                              --cuda-gpu-arch=${MUSA_BITCODE_ARCH} ${INCLUDE_DIRECTORIES} -DNVSHMEM_BITCODE_APPLICATION ${DIR_} -o ${NAME_}.bc.unoptimized
                      COMMAND ${MUSA_HOME}/bin/llvm-link --only-needed ${NAME_}.bc.unoptimized ${BITCODE_LIB_PATH} -o ${NAME_}.bc.unoptimized.linked
                      COMMAND ${MUSA_HOME}/bin/opt -O3 ${NAME_}.bc.unoptimized.linked -o ${NAME_}.bc
                      COMMAND ${MUSA_HOME}/bin/llc -O3 --disable-tail-calls -mcpu=${MUSA_BITCODE_ARCH} -filetype=obj ${NAME_}.bc -o ${MUBIN_NAME}
                      COMMAND rm -f ${NAME_}.bc.unoptimized ${NAME_}.bc.unoptimized.linked ${NAME_}.bc
                      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
                      DEPENDS nvshmem_perftest_helper ${BITCODE_LIB_PATH})
  else()
    set(BITCODE_LIB_PATH ${CMAKE_BINARY_DIR}/src/lib/libnvshmem_device.bc)
    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${MUBIN_NAME}
                      COMMAND ${MUSA_HOME}/bin/clang -c -emit-llvm -std=c++17 ${MUSA_MCC_FLAGS} --cuda-device-only
                              --cuda-gpu-arch=${MUSA_BITCODE_ARCH} ${INCLUDE_DIRECTORIES} -DNVSHMEM_BITCODE_APPLICATION ${DIR_} -o ${NAME_}.bc.unoptimized
                      COMMAND ${MUSA_HOME}/bin/llvm-link --only-needed ${NAME_}.bc.unoptimized ${BITCODE_LIB_PATH} -o ${NAME_}.bc.unoptimized.linked
                      COMMAND ${MUSA_HOME}/bin/opt -O3 ${NAME_}.bc.unoptimized.linked -o ${NAME_}.bc
                      COMMAND ${MUSA_HOME}/bin/llc -O3 --disable-tail-calls -mcpu=${MUSA_BITCODE_ARCH} -filetype=obj ${NAME_}.bc -o ${MUBIN_NAME}
                      COMMAND rm -f ${NAME_}.bc.unoptimized ${NAME_}.bc.unoptimized.linked ${NAME_}.bc
                      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
                      DEPENDS nvshmem_perftest_helper libnvshmem_device_bitcode)
  endif()

  add_custom_target(${NAME_}_mubin ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${MUBIN_NAME})

  install(
    FILES ${CMAKE_CURRENT_BINARY_DIR}/${MUBIN_NAME}
    DESTINATION "${NVSHMEM_PERFTEST_INSTALL_PREFIX}/${DIR}"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
  )
  if (NVSHMEM_PERFTEST_RELEASE_PREFIX)
    install(
            FILES ${CMAKE_CURRENT_BINARY_DIR}/${MUBIN_NAME}
            DESTINATION "${NVSHMEM_PERFTEST_RELEASE_PREFIX}/${DIR}"
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                        GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    )
  endif()
endmacro()

add_subdirectory(device)
add_subdirectory(host)
