#!/usr/bin/env bash

set -eu
cd

version="2.19.2"

case "$(uname -m)" in
x86_64) arch_name="amd64" ;;
aarch64) arch_name="arm64" ;;
*) echo "Unsupported arch: $(uname -m)" && exit 1 ;;
esac

wget -O "pandoc-$version.tar.gz" "https://github.com/jgm/pandoc/releases/download/$version/pandoc-$version-linux-$arch_name.tar.gz"
tar xf "pandoc-$version.tar.gz"
cp -a "pandoc-$version/bin/." "/usr/local/bin"

"/usr/local/bin/pandoc" --version
