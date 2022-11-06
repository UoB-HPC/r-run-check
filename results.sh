#!/usr/bin/env bash

set -eu

cd "/srv/scratch/persisted/tmp/R.check/r-release-gcc/work" || exit 1
ls -lah

name="ci-results-$(hostname)-$(date +"%d-%m-%Y")"

rm -rf "$name.tgz"
rm -rf "$name"
mkdir -p "$name/check"
mkdir -p "$name/install"

echo "Extracting results"
time (
    find build_dir -maxdepth 1 -name "*.check.out" -exec cp "{}" "$name/check/" \; &
    find build_dir -maxdepth 1 -name "*.install.out" -exec cp "{}" "$name/install/" \; &
    wait
)
echo "Compressing to $name.tgz"
tar czf "$name.tgz" "$name"
echo "Copying..."
cp "$name.tgz" /nfs/home/wl14928/
ls -lah "/nfs/home/wl14928/$name.tgz"
echo "Done"
