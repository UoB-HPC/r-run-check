#!/usr/bin/env bash

# Bioconductor appears to only support SSH for mirroring and we'll need to send our key to use master.bioconductor.org
# Because of this, we must use 3rd party ones, see https://bioconductor.org/about/mirrors/
# BioC_MIRROR="mirrors.dotsrc.org::bioconductor"
# BioC_MIRROR="ftp.gwdg.de::pub/misc/bioconductor"
# BioC_MIRROR="mirror.aarnet.edu.au::pub/bioconductor"

# CRAN_MIRROR="cran.r-project.org::CRAN"
# CRAN_MIRROR="ftp.gwdg.de::pub/misc/cran"
# CRAN_MIRROR="cran.csie.ntu.edu.tw::CRAN"

BioC_MIRROR="mirrors.dotsrc.org::bioconductor"
CRAN_MIRROR="cran.r-project.org::CRAN"
BioC_DEST="$HOME/CRAN_MIRROR/data/Bioconductor"
CRAN_DEST="$HOME/CRAN_MIRROR/data/CRAN"

# CRAN_MIRROR="cran.csie.ntu.edu.tw::CRAN"
# BioC_MIRROR="mirror.aarnet.edu.au::pub/bioconductor"
# BioC_DEST="/media/tom/CRAN_MIRROR/data/Bioconductor"
# CRAN_DEST="/media/tom/CRAN_MIRROR/data/CRAN"

do_sync() {
    local from=$1
    local to=$2
    mkdir -p "$to"
    rsync -rptlzv --info=progress2 --delete "$from" "$to"
}

(
    # BioC 3.15 
    do_sync "$BioC_MIRROR/packages/3.15/bioc/src/contrib" "$BioC_DEST/3.15/bioc/src" &
    do_sync "$BioC_MIRROR/packages/3.15/data/experiment/src/contrib" "$BioC_DEST/3.15/data/experiment/src" &
    do_sync "$BioC_MIRROR/packages/3.15/data/annotation/src/contrib" "$BioC_DEST/3.15/data/annotation/src" &
    # BioC 3.16 
    do_sync "$BioC_MIRROR/packages/3.16/bioc/src/contrib" "$BioC_DEST/3.16/bioc/src" &
    do_sync "$BioC_MIRROR/packages/3.16/data/experiment/src/contrib" "$BioC_DEST/3.16/data/experiment/src" &
    do_sync "$BioC_MIRROR/packages/3.16/data/annotation/src/contrib" "$BioC_DEST/3.16/data/annotation/src" &
    # CRAN
    do_sync "$CRAN_MIRROR/src/contrib" "$CRAN_DEST/src" &
wait
)
echo "Done!"
