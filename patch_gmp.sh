#!/usr/bin/env bash

set -eu

# GMP on el8 (CentOS 8/AlmaLinux 8, etc.) does not have a pkg-config pc file so we manually add that.

pkg-config --exists gmp || gmp_pc_exitcode=$?

if [[ ${gmp_pc_exitcode:-0} -eq 0 ]]; then
    echo "gmp.pc already exists, not patching" && exit 0
else echo "GMP not available in pkg-config, staring patch..."; fi

gmp_version=$(rpm -qa --queryformat '%{VERSION}' gmp)
if [[ -z "$gmp_version" ]]; then echo "Unable to determine GMP version" && exit 1; fi

tee -a "/usr/lib64/pkgconfig/gmp.pc" <<EOF
prefix=/usr
exec_prefix=/usr
includedir=/usr/include
libdir=/usr/lib64

Name: GNU MP
Description: GNU Multiple Precision Arithmetic Library
URL: https://gmplib.org
Version: ${gmp_version}
Cflags: -I\${includedir}
Libs: -L\${libdir} -lgmp
EOF

pkg-config --exists gmp || gmp_pc_exitcode=$?

if [[ ${gmp_pc_exitcode:-0} -ne 0 ]]; then
    echo "gmp.pc successfully installed"
else echo "gmp.pc installed but pkg-config returned $gmp_pc_exitcode" && exit 1; fi
