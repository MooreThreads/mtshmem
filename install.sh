#!/bin/bash
# Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

workdir="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"

op_type="install"
install_prefix=/usr/local/mtshmem

usage() {
    echo -e "mtshmem install script"
    echo -e "Usage:"
    echo -e "$0 <options>"
    echo -e "   [-i | --install]"
    echo -e "   [-u | --uninstall]"
    echo -e "   [-d | --prefix=<install_prefix>]"
    echo -e "   [-h | --help]"
    echo -e ""
}

die() {
    echo "$*" >&2;
    exit 2;
}

needs_arg() {
    if [ -z "$OPTARG" ]; then
        usage
        die "No arg for --$OPT option";
    fi;
}

element_in () {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 1; done
    return 0
}

install_func () {
    mkdir -p ${install_prefix}
    mkdir -p ${install_prefix}/lib
    mkdir -p ${install_prefix}/bin
    mkdir -p ${install_prefix}/include
    mkdir -p ${install_prefix}/share
    cp -v ./changelog ${install_prefix}/changelog
    cp -v ./License.txt ${install_prefix}/License.txt
    cp -v ./NOTICE ${install_prefix}/NOTICE
    cp -v ./install.sh ${install_prefix}/install.sh
    cp -v ./version.txt ${install_prefix}/version.txt
    cp -v ./git_commit.txt ${install_prefix}/git_commit.txt
    cp -r -P -v ./lib/* ${install_prefix}/lib/
    cp -r -P -v ./bin/* ${install_prefix}/bin/
    cp -r -v ./include/* ${install_prefix}/include/
    cp -r -v ./share/* ${install_prefix}/share/
    echo -E "Please export ${install_prefix}/lib to LD_LIBRARY_PATH in ~/.bashrc"
    echo -E "export LD_LIBRARY_PATH=${install_prefix}/lib:\${LD_LIBRARY_PATH}"
}

uninstall_func () {
    rm -rf ${install_prefix}/lib/libnvshmem*
    rm -rf ${install_prefix}/lib/nvshmem*
    rm -rf ${install_prefix}/bin/nvshmem*
    rm -rf ${install_prefix}/lib/cmake/nvshmem
    rm -rf ${install_prefix}/bin/examples/
    rm -rf ${install_prefix}/bin/perftest/
    rm -rf ${install_prefix}/include/bootstrap_device_host/
    rm -rf ${install_prefix}/include/device/
    rm -rf ${install_prefix}/include/device_host/
    rm -rf ${install_prefix}/include/device_host/transport/
    rm -rf ${install_prefix}/include/host/
    rm -rf ${install_prefix}/include/non_abi/
    rm -rf ${install_prefix}/include/nvshmem*
    rm -rf ${install_prefix}/share/src/
    rm -rf ${install_prefix}/changelog
    rm -rf ${install_prefix}/License.txt
    rm -rf ${install_prefix}/NOTICE
    rm -rf ${install_prefix}/install.sh
    rm -rf ${install_prefix}/version.txt
    rm -rf ${install_prefix}/git_commit.txt
    echo -E "Please remove following line in ~/.bashrc if necessary"
    echo -E "export LD_LIBRARY_PATH=${install_prefix}/lib:\${LD_LIBRARY_PATH}"
}

while getopts d:-:iuh OPT; do
    if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
        OPT="${OPTARG%%=*}"       # extract long option name
        OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
        OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    case "$OPT" in
        i | install )    op_type=install;;
        u | uninstall )    op_type=uninstall;;
        d | prefix )        needs_arg; install_prefix="$OPTARG";;
        h | help )          usage; exit 2;;
        ??* )               die "Illegal option --$OPT" ;;  # bad long option
        ? )                 exit 2 ;;  # bad short option (error reported via getopts)
    esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list
OTHER_ARGS=$@
OTHER_ARGS_TMP=( ${OTHER_ARGS} )
OTHER_ARGS_LEN=${#OTHER_ARGS_TMP[@]}
# echo "OTHER_ARGS: ${OTHER_ARGS}"

if [[ "$op_type" == "install" ]]; then
  echo "install mtshmem ..."
  install_func
fi

if [[ "$op_type" == "uninstall" ]]; then
  echo "uninstall mtshmem ..."
  uninstall_func
fi
