#!/bin/sh
set -e
set -x

SPECFILE="/source/$1"

yum install -y rpmdevtools yum-utils fakeroot

id -u builder &>/dev/null || useradd -s /bin/bash builder
mkdir -p /cache /source /result
chown builder. /cache -R

pushd /source
	spectool -g $SPECFILE
	yum-builddep -y $SPECFILE
popd

su builder -c /bin/bash <<EOF
set -e
set -x

mkdir -p /cache/builder-cache-dir
ln -sf /cache/builder-cache-dir ~/.cache

cat > ~/.rpmmacros <<EOT
%_topdir /tmp/buildd
EOT

mkdir -p /tmp/buildd/{BUILD,BUILDROOT,RPMS,SPECS,SRPMS}
ln -sfn /source /tmp/buildd/SOURCES

fakeroot-sysv rpmbuild -ba $SPECFILE
EOF

find /tmp/buildd/RPMS /tmp/buildd/SRPMS -type f |xargs -I{} -n1 cp {} /result
