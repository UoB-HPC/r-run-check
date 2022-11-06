#!/usr/bin/env bash

set -eu
cd

if ! command -v cmake3 &>/dev/null; then cmake3() { cmake "$@"; }; fi

version="3.10.1"

wget "https://github.com/Reference-LAPACK/lapack/archive/refs/tags/v$version.tar.gz"
tar xf "v$version.tar.gz"
cd "lapack-$version" || exit 1
cmake3 -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_INDEX64=OFF
# XXX Fortran is only supported in Ninja >= 1.10
# -GNinja

cmake3 --build build --target install -j "$(nproc)"
cd .. && rm -rf "v$version.tar.gz" "lapack-$version"
echo "Done"
