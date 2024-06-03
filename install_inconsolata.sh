#!/usr/bin/env bash

set -eu
cd

# see http://chingchuan-chen.github.io/posts/201909/2019-09-28-installation-in-centos-8.html

wget https://raw.githubusercontent.com/googlefonts/Inconsolata/main/fonts/ttf/Inconsolata-Regular.ttf
wget https://raw.githubusercontent.com/googlefonts/Inconsolata/main/fonts/ttf/Inconsolata-Bold.ttf
mv Inconsolata-Regular.ttf Inconsolata-Bold.ttf /usr/share/fonts
fc-cache /usr/share/fonts --verbose

wget https://mirrors.dotsrc.org/ctan/install/fonts/inconsolata.tds.zip
rm -rf inconsolata && mkdir -p inconsolata
unzip inconsolata.tds.zip -d inconsolata
cp -r inconsolata/* /usr/share/texmf
rm -rf inconsolata inconsolata.tds.zip
echo 'Map zi4.map\n' | tee -a /usr/share/texlive/texmf-dist/web2c/updmap.cfg
mktexlsr
yes | updmap-sys --enable Map=zi4.map --syncwithtrees --force
updmap -sys

echo "Done"
