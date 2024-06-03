#!/usr/bin/env bash

set -eu

RMZ_BIN=$PWD/rmz

cd "/srv/scratch/persisted/tmp/" || exit 1
ls -lah

name="ci-results-$(hostname)-$(date +"%d-%m-%Y_%H%M")"

rm -rf "$name.tgz"
rm -rf "$name"

mkdir -p "$name"
# mkdir -p "$name/install"

echo "Extracting results ..."

time mv ./install_logs "$name" || true
time mv ./check_logs "$name" || true
time mv ./*.log "$name" || true
time mv ./*.yml "$name" || true
time mv ./*.json "$name" || true
time mv ./Makevars.* "$name" || true

echo "Compressing to $name.tgz"
time tar --use-compress-program="pigz --best --recursive | pv" -cf "$name.tgz" "$name"

echo "Removing residuals..."
time $RMZ_BIN -f ./*


user_home=$(eval echo "~$SUDO_USER")
echo "Unprivileged user is $SUDO_USER ($user_home)"
echo "Moving $name to $user_home ..."
mv "$name.tgz" "$user_home"
chown "$SUDO_USER" "$user_home/$name.tgz"
ls -lah "$user_home/$name.tgz"
echo "Done"
