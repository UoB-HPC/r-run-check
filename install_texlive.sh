#!/usr/bin/env bash

set -eu
cd

variant="${1:-latest}"
prefix="${2:-latest}"

repo="$PWD/tlnet"

rclone sync \
    --http-url https://anorien.csc.warwick.ac.uk \
    :http:/mirrors/CTAN/systems/texlive/tlnet/ \
    "$repo" \
    --progress --transfers=32 -L

echo "Done!"

# See https://tug.org/texlive/doc/install-tl.html
# wget "$repo/install-tl-unx.tar.gz"
tar xvf "$repo/install-tl-unx.tar.gz" # && rm -rf install-tl-unx.tar.gz
cd "install-tl-"* || exit 1

perl ./install-tl \
    -repository "$repo" \
    --no-interaction \
    --texdir "/usr/local/texlive/${variant}" \
    --texmfsysvar "/usr/local/texlive/${variant}/texmf-var" \
    --texmfsysconfig "/usr/local/texlive/${variant}/texmf-config" \
    --texmfvar "$HOME/.texlive${variant}/texmf-var" \
    --texmfconfig "$HOME/.texlive${variant}/texmf-config"

cd .. && rm -rf "$repo"

export TEXLIVE_BIN="/usr/local/texlive/$variant/bin/$(uname -m)-linux"
echo "TEXLIVE_BIN=${TEXLIVE_BIN}"
echo "Done"
