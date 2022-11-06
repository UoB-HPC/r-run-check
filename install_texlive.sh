#!/usr/bin/env bash

set -eu
cd

variant="${1:-latest}"

# See https://tug.org/texlive/doc/install-tl.html
wget "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz"
tar xvf install-tl-unx.tar.gz && rm -rf install-tl-unx.tar.gz
cd "install-tl-"* || exit 1

perl ./install-tl \
    --no-interaction \
    --texdir "/usr/local/texlive/${variant}" \
    --texmfsysvar "/usr/local/texlive/${variant}/texmf-var" \
    --texmfsysconfig "/usr/local/texlive/${variant}/texmf-config" \
    --texmfvar "$HOME/.texlive${variant}/texmf-var" \
    --texmfconfig "$HOME/.texlive${variant}/texmf-config"

cd .. && rm -rf "install-tl-"*

TEXLIVE_BIN="/usr/local/texlive/$variant/bin/$(uname -m)-linux"
export TEXLIVE_BIN
echo "TEXLIVE_BIN=${TEXLIVE_BIN}"
