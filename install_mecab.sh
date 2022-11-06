#!/usr/bin/env bash

set -eu
cd

version="0.996"

# Google Drive as per instructed on https://taku910.github.io/mecab/#download
wget --content-disposition "https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7cENtOXlicTFaRUE"
tar xf "mecab-$version.tar.gz"
cd "mecab-$version" || exit 1
./configure --build="$(uname -m)-unknown-linux-gnu"
make -j "$(nproc)" && make install
cd .. && rm -rf "mecab-$version.tar.gz" "mecab-$version"
echo "Done"
