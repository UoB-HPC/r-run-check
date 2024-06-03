#!/usr/bin/env bash

set -eu
cd

# TODO incomplete! 

dnf install -y atkmm-devel glibmm24-devel pangomm-devel gtk2-devel

wget "http://ftp.gnome.org/pub/GNOME/sources/gtkmm/2.24/gtkmm-2.24.5.tar.xz"
tar xf "gtkmm-2.24.5.tar.xz"
cd "gtkmm-2.24.5" || exit 1
# FIXME fails on Alma9
# ./configure  
make -j "$(nproc)" && make install
cd .. && rm -rf "gtkmm-2.24.5.tar.xz" "gtkmm-2.24.5"
echo "Done"
