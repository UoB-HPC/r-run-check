#!/usr/bin/env bash

# FIXME OpenBUGS is written in Component Pascal and requires BlackBox Component Builder
# This toolchain appears to be only maintained for Win32 platforms, compilation
# requires interaction with the IDE.
# The "source" package available on Cambridge's website ships an i686 ELF dso in the tarball and a
# small shim program to expose the entry points.

# Possible solution for non i686 platform: OberonCore (https://oberoncore.ru/) has an OSS Linux
# version, although it's not clear whether it's compatible with the binary-based source code of OpenBUGS.

set -eu
cd

version="3.2.3"

case "$(uname -m)" in
x86_64)
    dnf install -y glibc-devel.i686
    ;;
i686)
    # nothing to do
    ;;
aarch64)
    echo "OpenBUGS is not available for non i686 or x86_64 platforms."
    exit 0
    ;;
*)
    echo "Unknown arch: $(uname -m)"
    exit 1
    ;;
esac

wget "https://www.mrc-bsu.cam.ac.uk/wp-content/uploads/2018/04/OpenBUGS-$version.tar.gz"
tar xf "OpenBUGS-$version.tar.gz"
cd "OpenBUGS-$version" || exit 1
./configure
make -j "$(nproc)" && make install
cd .. && rm -rf "OpenBUGS-$version.tar.gz" "OpenBUGS-$version"
echo "Done"
