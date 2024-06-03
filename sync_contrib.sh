#!/usr/bin/env bash

PARALLEL=32
BIOC_VERSION="3.19"

# BIOC_MIRROR="https://mirrors.dotsrc.org"
# CRAN_MIRROR="https://mirrors.dotsrc.org"

BIOC_MIRROR="https://ftp.gwdg.de"
CRAN_MIRROR="https://ftp.gwdg.de"

DEST=${1:-"$HOME/r-contrib"}

do_sync() {
    local mirror=$1
    local from=$2
    local to=$3

    mkdir -p "$to"

    rclone sync \
        --http-url "$mirror" \
        ":http:$from" \
        "$to" \
        --progress --delete-before --transfers=$PARALLEL --checkers=$((PARALLEL * 4)) -L

}

# BioC
do_sync "$BIOC_MIRROR" "pub/misc/bioconductor/packages/$BIOC_VERSION/bioc/src/contrib" "$DEST/bioconductor/packages/$BIOC_VERSION/bioc/src/contrib"
do_sync "$BIOC_MIRROR" "pub/misc/bioconductor/packages/$BIOC_VERSION/data/experiment/src/contrib" "$DEST/bioconductor/packages/$BIOC_VERSION/data/experiment/src/contrib"
do_sync "$BIOC_MIRROR" "pub/misc/bioconductor/packages/$BIOC_VERSION/data/annotation/src/contrib" "$DEST/bioconductor/packages/$BIOC_VERSION/data/annotation/src/contrib"

# CRAN
do_sync "$CRAN_MIRROR" "pub/misc/cran/src/contrib" "$DEST/cran/src/contrib"
echo "Done!"
