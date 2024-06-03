#!/usr/bin/env bash

set -eu

trap abort INT

abort() {
    jobs -p
    kill "$(jobs -p)"
    echo "Abort"
}

name="$1"
variant="gcc"
r_flavour="r-devel"

R_HOME="$("$HOME/tmp/R.check/$r_flavour-$variant/work/build/bin/R" RHOME)"
export R_HOME
R_PROFILE_USER="$HOME/src/check_CRAN_regular.Rprofile"
export R_PROFILE_USER
R_CHECK_ENVIRON="$HOME/src/check_CRAN_regular.Renviron"
export R_CHECK_ENVIRON
R_MAKEVARS_USER="$HOME/src/Makevars-$variant"
export R_MAKEVARS_USER

cd "$HOME/tmp/R.check/$r_flavour-$variant/work/build_dir" || exit 1
echo "### Running check for $name"

rm -rf "$name.check.out"
# killall tail
time make -f Makefile.check --always-make -n "$name.check.ts1"
# (
#     time make -f Makefile.check --always-make "$name.check.ts1" &
#     tail -F "$name.check.out"
# )
echo "### Done check for $name"
