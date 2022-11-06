#!/usr/bin/env bash

set -eu

# MPFR on el8 (CentOS 8/AlmaLinux 8, etc.) does not have a pkg-config pc file so we manually add that.

pkg-config --exists mpfr || mpfr_pc_exitcode=$?

if [[ ${mpfr_pc_exitcode:-0} -eq 0 ]]; then
    echo "mpfr.pc already exists, not patching" && exit 0
else echo "MPFR not available in pkg-config, staring patch..."; fi

mpfr_version=$(rpm -qa --queryformat '%{VERSION}' mpfr)
if [[ -z "$mpfr_version" ]]; then echo "Unable to determine MPFR version" && exit 1; fi

tee -a "/usr/lib64/pkgconfig/mpfr.pc" <<EOF
prefix=/usr
exec_prefix=/usr
libdir=/usr/lib64
includedir=/usr/include

Name: mpfr
URL: https://www.mpfr.org/
Description: C library for multiple-precision floating-point computations
Version: ${mpfr_version}
Libs: -L\${libdir} -lmpfr -lgmp
Cflags: -I\${includedir}

EOF

pkg-config --exists mpfr || mpfr_pc_exitcode=$?

if [[ ${mpfr_pc_exitcode:-0} -ne 0 ]]; then
    echo "mpfr.pc successfully installed"
else echo "mpfr.pc installed but pkg-config returned $mpfr_pc_exitcode" && exit 1; fi
