#!/usr/bin/env bash

rclone sync \
    --http-url https://anorien.csc.warwick.ac.uk \
    :http:/mirrors/CTAN/systems/texlive/tlnet/ \
    /srv/CRAN_MIRROR/data/CTAN \
    --progress --transfers=32 -L

echo "Done!"
