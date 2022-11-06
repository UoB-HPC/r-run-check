#!/usr/bin/env bash

set -eu
cd

if ! command -v cmake3 &>/dev/null; then cmake3() { cmake "$@"; }; fi

version="3.5.2"

wget "https://github.com/OSGeo/gdal/releases/download/v$version/gdal-$version.tar.gz"
tar xf "gdal-$version.tar.gz"
cd "gdal-$version" || exit 1
cmake3 -Bbuild -H. -DCMAKE_BUILD_TYPE=Release -GNinja
cmake3 --build build --target install
cd .. && rm -rf "gdal-$version.tar.gz" "gdal-$version"
echo "Done"
