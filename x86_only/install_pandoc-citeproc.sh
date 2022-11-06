#!/usr/bin/env bash

set -eu
cd

version="473378e"

wget "https://github.com/jgm/pandoc-citeproc/archive/$version.tar.gz"
tar xf "$version.tar.gz"
cd "pandoc-citeproc-$version"* || exit 1
export PATH="$HOME/.ghcup/bin:${PATH:-}"
stack setup
stack install \
    --jobs "$(nproc)" \
    --flag "pandoc:embed_data_files" \
    --flag "pandoc-citeproc:embed_data_files" \
    --local-bin-path "/usr/local/bin"

cd .. && rm -rf "$version.tar.gz" "pandoc-citeproc-$version"*
pandoc-citeproc --version
ldd /usr/local/bin/pandoc-citeproc
