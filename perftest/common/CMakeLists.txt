add_library(nvshmem_perftest_utils OBJECT ${CMAKE_CURRENT_SOURCE_DIR}/utils.cu)
set_source_files_properties(utils.cu PROPERTIES LANGUAGE CXX)
target_include_directories(nvshmem_perftest_utils PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_BINARY_DIR}/src/include
)
mtshmem_enable_musa_rdc(nvshmem_perftest_utils)

add_library(nvshmem_perftest_helper INTERFACE)
target_link_libraries(nvshmem_perftest_helper INTERFACE MUSA::musart MUSA::musa_driver)
target_include_directories(nvshmem_perftest_helper INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_features(nvshmem_perftest_helper INTERFACE cxx_std_17)

if(NVSHMEM_SHMEM_SUPPORT)
  target_link_libraries(nvshmem_perftest_helper INTERFACE shmem)
  target_compile_definitions(nvshmem_perftest_helper INTERFACE NVSHMEMTEST_SHMEM_SUPPORT)
endif()
if(NVSHMEM_MPI_SUPPORT)
  target_link_libraries(nvshmem_perftest_helper INTERFACE MPI::MPI_CXX)
  target_compile_definitions(nvshmem_perftest_helper INTERFACE NVSHMEMTEST_MPI_SUPPORT)
endif()
