#!/usr/bin/env bash

set -eu
cd
dnf install -y libaio

case "$(uname -m)" in
x86_64)
    code="217000"
    version="21.7.0.0.0-1"
    wget "https://download.oracle.com/otn_software/linux/instantclient/$code/oracle-instantclient-basic-$version.el8.x86_64.rpm"
    wget "https://download.oracle.com/otn_software/linux/instantclient/$code/oracle-instantclient-devel-$version.el8.x86_64.rpm"
    rpm -Uvh "oracle-instantclient-basic-$version.el8.x86_64.rpm"
    rpm -Uvh "oracle-instantclient-devel-$version.el8.x86_64.rpm"
    rm -rf "oracle-instantclient-basic-$version.el8.x86_64.rpm" "oracle-instantclient-devel-$version.el8.x86_64.rpm"
    ;;
aarch64)
    code="191000"
    version="19.10.0.0.0-1"
    version_name="19.10"
    wget "https://download.oracle.com/otn_software/linux/instantclient/$code/oracle-instantclient$version_name-basic-$version.aarch64.rpm"
    wget "https://download.oracle.com/otn_software/linux/instantclient/$code/oracle-instantclient$version_name-devel-$version.aarch64.rpm"
    rpm -Uvh "oracle-instantclient$version_name-basic-$version.aarch64.rpm"
    rpm -Uvh "oracle-instantclient$version_name-devel-$version.aarch64.rpm"
    rm -rf "oracle-instantclient$version_name-basic-$version.aarch64.rpm" "oracle-instantclient$version_name-devel-$version.aarch64.rpm"
    ;;
*)
    echo "Unsupported arch: $(uname -m)"
    exit 1
    ;;
esac

echo "Done"
