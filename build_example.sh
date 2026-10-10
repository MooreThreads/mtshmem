#!/bin/bash
THIS_DIR=$(cd `dirname $0`; pwd)
MUSA_PATH=${MUSA_HOME:-/usr/local/musa}
MAKE_PATH=${THIS_DIR}/build
ARCH=mp_31
MCC=${MUSA_PATH}/bin/mcc
LIB=${MAKE_PATH}/src/lib

mkdir -p ${MAKE_PATH}/examples

build_musa () {
  echo "======== building ${SRC_NAME} ======="
  OBJ=${MAKE_PATH}/examples/${SRC_NAME%.cu}.o
  OUT=${MAKE_PATH}/examples/${SRC_NAME%.cu}.out
  ${MCC} -x musa -fgpu-rdc --offload-arch=${ARCH} -c \
    -I${THIS_DIR}/src/include \
    ${THIS_DIR}/examples/${SRC_NAME} -o ${OBJ}
  ${MCC} -rdc=true --offload-arch=${ARCH} ${OBJ} \
    ${LIB}/libnvshmem_device.a ${LIB}/libnvshmem_host.a \
    -o ${OUT} -L${MUSA_PATH}/lib -lmusart
}

SRC_NAME=dev-guide-ring.cu
build_musa

SRC_NAME=hello.cpp
${MCC} -x musa -std=c++11 -c \
  -I${THIS_DIR}/src/include \
  ${THIS_DIR}/examples/${SRC_NAME} -o ${MAKE_PATH}/examples/hello.o
${MCC} ${MAKE_PATH}/examples/hello.o ${LIB}/libnvshmem.a \
  -o ${MAKE_PATH}/examples/hello.out -L${MUSA_PATH}/lib -lmusart

SRC_NAME=collective-launch.cu
build_musa

SRC_NAME=on-stream.cu
build_musa

SRC_NAME=put-block.cu
build_musa

SRC_NAME=ring-bcast.cu
build_musa

SRC_NAME=thread-group.cu
build_musa

SRC_NAME=alltoall.cu
build_musa
