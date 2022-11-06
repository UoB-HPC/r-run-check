#!/usr/bin/env bash

set -eu
cd

version="4.3.1"

wget "https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Source/JAGS-$version.tar.gz"
tar xf "JAGS-$version.tar.gz"
cd "JAGS-$version" || exit 1
./configure
make -j "$(nproc)" && make install
cd .. && rm -rf "JAGS-$version.tar.gz" "JAGS-$version"
echo "Done"
