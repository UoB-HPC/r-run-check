#!/usr/bin/env bash

set -eu
cd

version="2.19.2"

wget "https://github.com/jgm/pandoc/archive/refs/tags/$version.tar.gz"
tar xf "$version.tar.gz"
cd "pandoc-$version" || exit 1
export PATH="$HOME/.ghcup/bin:${PATH:-}"
stack setup
stack install \
    --system-ghc \
    --jobs "$(nproc)" \
    --flag "pandoc:embed_data_files" \
    --local-bin-path "/usr/local/bin"

cd .. && rm -rf "pandoc-$version.tar.gz" "pandoc-$version"
pandoc --version
ldd /usr/local/bin/pandoc
