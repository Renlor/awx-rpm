#!/usr/bin/env bash

export IFS=" "

set -o errexit
set -o nounset
set -o pipefail
set -o noclobber

readonly script_dir="$(readlink -f "$(dirname "${0}")")"
readonly project_dir="${script_dir}"
readonly config_dir="${script_dir}/config"

# BUILD swig 2.0 for centos 6
yum install -y \
  automake \
  gcc \
  pcre-devel \
  byacc \
  gcc-c++ \
  bison \
  boost \
  rpm-build \
  python27-runtime \
  python27-python-virtualenv \
  python27-python \
  python27-python-setuptools \
  python27-python-devel \
  python27-python-libs \
  python27-python-pip \
  python27-python-wheel \

set +o nounset
set +o errexit
. /opt/rh/python27/enable
set -o nounset
set -o errexit

readonly swig_build_dir="${project_dir}/build-swig"
rm -rf "${swig_build_dir}"
mkdir -p "${swig_build_dir}"

pushd "${swig_build_dir}"

  readonly swig_name="swig-2.0.12"
  readonly swig_tar_name="swig-2.0.12.tar.gz"
  readonly swig_tar="${swig_build_dir}/${swig_tar_name}"
  readonly swig_source_dir="${swig_build_dir}/${swig_name}"
  readonly swig_rpmbuild_dir="${swig_build_dir}/rpmbuild"

  for i in SOURCES SPECS BUILD BUILDROOT RPMS SRPMS ; do 
    mkdir -p "${swig_rpmbuild_dir}/${i}"
  done

  #dev release: https://codeload.github.com/swig/swig/tar.gz/rel-2.0.12
  #user release: https://sourceforge.net/projects/swig/files/swig/swig-2.0.12/swig-2.0.12.tar.gz
  #wget -O "${swig_tar}"  "https://sourceforge.net/projects/swig/files/swig/${swig_name}/${swig_tar_name}"
  cp "/repo/${swig_tar_name}" "${swig_tar}"
  ln -sf "${swig_tar}" "${swig_rpmbuild_dir}/SOURCES/${swig_tar_name}"

  tar -xvf "${swig_tar}"
  pushd "${swig_source_dir}"
    ./autogen.sh
    ./configure
  popd
  cp "${swig_source_dir}/swig.spec" "${swig_rpmbuild_dir}/SPECS"

  rpmbuild --define "_topdir ${swig_rpmbuild_dir}" -ba "${swig_rpmbuild_dir}/SPECS/swig.spec"
  yum remove -y 'swig-2.0.12-1.x86_64'
  yum install -y "${swig_rpmbuild_dir}/RPMS/x86_64/swig-2.0.12-1.x86_64.rpm"

popd

# BUILD proot

yum install -y libtalloc-devel

readonly proot_build_dir="${project_dir}/build-proot"
rm -rf "${proot_build_dir}"
mkdir -p "${proot_build_dir}"

pushd "${proot_build_dir}"
  readonly proot_name="PRoot-5.1.0"
  readonly proot_tar_name="PRoot-5.1.0.tar.gz"
  readonly proot_tar="${proot_build_dir}/${proot_tar_name}"
  readonly proot_source_dir="${proot_build_dir}/${proot_name}/src"

  cp "/repo/${proot_tar_name}" "${proot_tar}"
  tar -xvf "${proot_tar}"
  pushd "${proot_source_dir}"
    make
    make install
    readonly proot_binary="${proot_source_dir}/proot"
  popd

popd


yum install -y \
  rh-postgresql95-runtime \
  rh-postgresql95-postgresql-server \
  rh-postgresql95-postgresql-devel \
  rh-git29 \
  rh-nodejs6-runtime \
  rh-nodejs6-npm \
  openssl-devel \
  libxml2-devel \
  xmlsec1-devel \
  openldap-devel \
  xmlsec1-openssl-devel \
  libtool-ltdl-devel \
  libcurl-devel \
  libffi-devel \
  libyaml-devel \
  apr \
  apr-util \
  neon \
  pakchois \
  perl-URI \
  subversion \

set +o nounset
set +o errexit
. /opt/rh/rh-git29/enable
. /opt/rh/rh-postgresql95/enable
. /opt/rh/rh-nodejs6/enable
set -o nounset
set -o errexit

readonly awx_build_dir="${project_dir}/build-awx"
readonly awx_rpmbuild_dir="${awx_build_dir}/rpmbuild"

rm -rf "${awx_build_dir}"
mkdir -p "${awx_build_dir}"

for i in SOURCES SPECS BUILD BUILDROOT RPMS SRPMS ; do 
  mkdir -p "${awx_rpmbuild_dir}/${i}"
done

pushd "${awx_build_dir}"
  git clone "/repo/awx"
  pushd "./awx"
    git checkout '4df4d7366ef9349086b4b855acf6d606cb41630b'
    # Patch local issue
    sed -i 's;en-us;en_US.UTF-8;g' 'Makefile'
    sed -i 's;git+https://git@github.com;git+file:///repo/npm;g' './awx/ui/package.json'

    make sdist
    cp "./dist/awx-1.0.6.16.tar.gz" "${awx_rpmbuild_dir}/SOURCES/"
  popd

  service network stop

  cp "${proot_binary}"  "${awx_rpmbuild_dir}/SOURCES/"
  cp "${config_dir}/awx-build-offline.spec" "${awx_build_dir}/awx.spec"
#  cp "${config_dir}/awx-build.spec" "${awx_build_dir}/awx.spec"
  cp -a "${config_dir}/settings.py.dist" "${awx_build_dir}/SOURCES/"
  cp -a "${config_dir}/nginx.conf.example" "${awx_build_dir}/SOURCES/"
  cp -a "${config_dir}/centos/6/" "${awx_build_dir}/SOURCES/"
  # TODO: create patches to convert back to proot from bubblewrap
  rpmbuild --define "_topdir ${awx_rpmbuild_dir}" -ba "${awx_build_dir}/awx.spec"
popd

# System configuration
# from: 
#   https://github.com/rabbitmq/erlang-rpm/releases/download/v20.3.6/erlang-20.3.6-1.el6.x86_64.rpm
#   https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.7.6/rabbitmq-server-3.7.6-1.el6.noarch.rpm
#   https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/s/socat-1.7.2.3-1.el6.x86_64.rpm
yum remove -y socat erlang rabbitmq-server
yum install -y \
  /repo/socat-1.7.2.3-1.el6.x86_64.rpm \
  /repo/erlang-20.3.6-1.el6.x86_64.rpm \
  /repo/rabbitmq-server-3.7.6-1.el6.noarch.rpm

# TODO: check hostname resolution
chkconfig rabbitmq-server on
service rabbitmq-server start

postgresql-setup --initdb --unit rh-postgresql95-postgresql
chkconfig rh-postgresql95-postgresql on
service rh-postgresql95-postgresql start
su postgres -c \"createuser -S awx\"
su postgres -c \"createdb -O awx awx\"

service memcached start

cp -f "${config_dir}/centos/6/nginx.conf" "/etc/opt/rh/rh-nginx110/nginx/nginx.conf"
chkconfig rh-nginx110-nginx on
service rh-nginx110-nginx start

for s in awx-cbreceiver awx-celery-beat awx-celery-worker awx-channels-worker awx-daphne awx-web ; do
  chkconfig ${s} on
  service ${s} start
done
