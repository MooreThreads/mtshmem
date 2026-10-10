# This file has been modified by Moore Threads Technology Co., Ltd.
# Modifications for MTSHMEM are Copyright (c) 2026-2026 Moore Threads Technology Co., Ltd.

# Copyright (c) 2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

include(CheckCXXCompilerFlag)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|ARM64|arm64)")
    set(ARCH_NAME "aarch64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)")
    set(ARCH_NAME "x86_64")
else()
    message(FATAL_ERROR "Unsupported architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

function(BuildWheel WHEEL_TARGET PY_VER PYTHON_EXECUTABLE)

    set(PYPROJECT_TOML "${CMAKE_SOURCE_DIR}/nvshmem4py/pyproject.toml")
    set(BUILD_DIR "${CMAKE_BINARY_DIR}/nvshmem4py/dist")
    set(MUSA_INCLUDE_DIR "$ENV{MUSA_HOME}/include")
    if(NOT EXISTS "${MUSA_INCLUDE_DIR}/musa_runtime_api.h")
        set(MUSA_INCLUDE_DIR "/usr/local/musa/include")
    endif()


    set(PY_DEPS_DIR "${CMAKE_BINARY_DIR}/nvshmem4py/externals/pydeps_${PY_VER}")
    set(PY_DEPS_STAMP "${PY_DEPS_DIR}/.prepared")

    if(NOT TARGET prepare_python_${PY_VER})
        add_custom_command(
            OUTPUT ${PY_DEPS_STAMP}
            COMMAND ${CMAKE_COMMAND} -E rm -rf ${PY_DEPS_DIR}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${PY_DEPS_DIR}
            COMMAND ${PYTHON_EXECUTABLE} -m pip install --upgrade --target ${PY_DEPS_DIR} -r ${CMAKE_SOURCE_DIR}/nvshmem4py/requirements_build.txt
            COMMAND ${CMAKE_COMMAND} -E touch ${PY_DEPS_STAMP}
            DEPENDS ${CMAKE_SOURCE_DIR}/nvshmem4py/requirements_build.txt
            COMMENT "Preparing Python ${PY_VER} wheel dependencies"
            VERBATIM
        )
        add_custom_target(prepare_python_${PY_VER} DEPENDS ${PY_DEPS_STAMP})
    endif()


    set(PYPROJECT_PATH "${CMAKE_SOURCE_DIR}/nvshmem4py/pyproject.toml")
    set(SETUP_PATH "${CMAKE_SOURCE_DIR}/nvshmem4py/setup.py")
    message("BUILD DIR IS ${BUILD_DIR}")
    message("BINARY DIR IS ${CMAKE_BINARY_DIR}")
    message("SOURCE DIR IS ${CMAKE_SOURCE_DIR}")
    message("MUSA INCLUDE DIR IS ${MUSA_INCLUDE_DIR}")

    set(WHEEL_NAME "nvshmem4py")
    set(WHEEL_STR "nvshmem4py")

    add_custom_target(
        ${WHEEL_TARGET}
        COMMAND echo "Building MUSA wheel ${WHEEL_NAME}"
        COMMAND mkdir -p ${BUILD_DIR}
        COMMAND ${CMAKE_COMMAND} -E rm -f ${BUILD_DIR}/${WHEEL_STR}*.whl ${BUILD_DIR}/${WHEEL_STR}*.tar.gz
        COMMAND ${CMAKE_COMMAND} -E env
                "CPPFLAGS=-I${MUSA_INCLUDE_DIR} -I${CMAKE_SOURCE_DIR}/src/include"
                "PACKAGE_NAME=${WHEEL_NAME}"
                "MUSA_HOME=$ENV{MUSA_HOME}"
                "PYTHONPATH=${PY_DEPS_DIR}:$ENV{PYTHONPATH}"
                "PATH=${PY_DEPS_DIR}/bin:$ENV{PATH}"
                ${PYTHON_EXECUTABLE} -m build --no-isolation --outdir ${BUILD_DIR}
        COMMAND bash -c "export PATH=${PY_DEPS_DIR}/bin:$PATH; export PYTHONPATH=${PY_DEPS_DIR}:$PYTHONPATH; ls ${BUILD_DIR}/${WHEEL_STR}*.whl | xargs ${PYTHON_EXECUTABLE} -m auditwheel repair --plat manylinux_2_34_${ARCH_NAME} -w ${BUILD_DIR}/"
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/nvshmem4py/
        COMMAND echo "Listing outdir ${BUILD_DIR} for MUSA packages"
        COMMAND ls ${BUILD_DIR}
        USES_TERMINAL
        COMMENT "Building Python wheel and tarball..."
        VERBATIM
    )

    if(TARGET build_bindings_cybind)
        add_dependencies(${WHEEL_TARGET} build_bindings_cybind)
    endif()

    add_dependencies(${WHEEL_TARGET} prepare_python_${PY_VER})


endfunction()
