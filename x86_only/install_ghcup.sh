#!/usr/bin/env bash

set -eu
cd

# wget -O ghcup "https://downloads.haskell.org/~ghcup/$(uname -m)-linux-ghcup"
# chmod +x ghcup
# mv ghcup /usr/local/bin
# ghcup install stack
# ghcup install ghc --set 9.0.2
# ghcup install cabal --set 3.8
# export PATH="$HOME/.ghcup/bin:${PATH:-}"
# stack config set install-ghc false --global
# stack config set system-ghc true --global

wget -O get-ghcup.sh "https://get-ghcup.haskell.org"
chmod +x get-ghcup.sh
BOOTSTRAP_HASKELL_NONINTERACTIVE=1 ./get-ghcup.sh
source /root/.ghcup/env
rm -rf get-ghcup.sh
