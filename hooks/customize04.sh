#!/bin/sh
set -e

chroot "$1" ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
echo "$TIMEZONE" > "$1/etc/timezone"
chroot "$1" dpkg-reconfigure -f noninteractive tzdata
