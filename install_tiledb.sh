#!/usr/bin/env bash

set -eu
cd

dnf install -y zip perl

version="2.23.0"
hash="152093b"

wget "https://github.com/TileDB-Inc/TileDB/releases/download/$version/tiledb-source-$version-$hash.tar.gz"
mkdir tiledb && tar xf "tiledb-source-$version-$hash.tar.gz" -C tiledb
cd tiledb || exit 1

mkdir build
(
    cd build
    ln -s /usr/bin/g++ aarch64-linux-gnu-g++
    ln -s /usr/bin/gcc aarch64-linux-gnu-gcc
    export PATH="$PWD:$PATH"
    export VCPKG_FORCE_SYSTEM_BINARIES=1
    ../bootstrap --prefix=/usr/local
    make -j "$(nproc)"
    make install-tiledb
)
cd .. && rm -rf "tiledb-source-$version-$hash.tar.gz" tiledb
echo "Done"
