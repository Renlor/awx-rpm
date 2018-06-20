#!/usr/bin/env bash

export IFS=" "

set -o errexit
set -o nounset
set -o pipefail
set -o noclobber

mkdir -p /tmp/awx-rpmbuild-cache

readonly script_dir="$(readlink -f "$(dirname "${0}")")"
readonly project_dir="${script_dir}"
readonly config_dir="${project_dir}/config"
readonly build_dir="${project_dir}/build"
readonly build_script="${project_dir}/rpmbuild.sh"

case "${1}" in
    "amazonlinux-2017.03")
        docker_image=ctbuild/amazonlinux:2017.03
        os='amazonlinux'
        version='2017.03'
    ;;
    "centos-7")
        docker_image=ctbuild/centos:7
        os='centos'
        version='7'
    ;;
    "centos-6")
        docker_image=ctbuild/centos:6
        os='centos'
        version='6'
    ;;
    *)
        echo "Usage: $0 [centos-6|centos-7|amazonlinux-2017.03]"
        exit 1
esac

readonly os_dir="${config_dir}/${os}/${version}"

rm -rf "${build_dir}"

mkdir -p "${build_dir}"

cp -a "${os_dir}/." "${build_dir}/"

exec docker run --rm -i \
    -v ${os_dir}:/source \
    -v ${project_dir}/result:/result \
    -v /tmp/awx-rpmbuild-cache:/cache \
    -v ${os_dir}/yum.conf:/etc/yum.conf \
    -v $build_script:/rpmbuild.sh \
    $docker_image /rpmbuild.sh awx-build.spec
