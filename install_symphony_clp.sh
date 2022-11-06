#!/usr/bin/env bash

set -eu
cd

version="5.6.19"

wget "https://raw.githubusercontent.com/coin-or/coinbrew/master/coinbrew"
chmod u+x coinbrew
./coinbrew fetch "SYMPHONY@releases/$version"
./coinbrew build SYMPHONY -j "$(nproc)" \
    --verbosity=3 \
    --tests=none \
    --build="$(uname -m)-unknown-linux-gnu" \
    --prefix=/usr/local
# SYMPHONY also pulls in Clp so we'll have both
rm -rf coinbrew SYMPHONY Osi Clp Cgl CoinUtils Data ThirdParty build
echo "Done"
