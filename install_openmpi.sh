#!/usr/bin/env bash

set -eu
cd

major="4.1"
minor=".4"

wget "https://download.open-mpi.org/release/open-mpi/v$major/openmpi-$major$minor.tar.gz"
tar xf "openmpi-$major$minor.tar.gz"
cd "openmpi-$major$minor" || exit 1
./configure
make -j "$(nproc)" && make install
cd .. && rm -rf "openmpi-$major$minor.tar.gz" "openmpi-$major$minor"
echo "Done"
