#!/usr/bin/env bash

set -eu
cd

if ! command -v cmake3 &>/dev/null; then cmake3() { cmake "$@"; }; fi

# FIXME What about Debian?
dnf install -y sqlite-devel

version="7.2.1"

# XXX We use the latest (possibly the last) release of PROJ7.
# PROJ >= 8 removes the PROJ4 API, many R packages haven't done the migration, see https://proj.org/news.html#id210
wget "https://download.osgeo.org/proj/proj-$version.tar.gz"
tar xf "proj-$version.tar.gz"
cd "proj-$version" || exit 1
cmake3 -Bbuild -H. -DCMAKE_BUILD_TYPE=Release -GNinja
cmake3 --build build --target install
cd .. && rm -rf "proj-$version.tar.gz" "proj-$version"
echo "Done"
