#!/usr/bin/env bash

set -eu
cd

if ! command -v cmake3 &>/dev/null; then cmake3() { cmake "$@"; }; fi

version="5.19.7"

wget "https://github.com/sbmlteam/libsbml/archive/refs/tags/v$version.tar.gz"
tar xf "v$version.tar.gz"
cd "libsbml-$version" || exit 1
cmake3 -Bbuild -H. -DCMAKE_BUILD_TYPE=Release -GNinja
cmake3 --build build --target install
cd .. && rm -rf "v$version.tar.gz" "libsbml-$version"
echo "Done"
