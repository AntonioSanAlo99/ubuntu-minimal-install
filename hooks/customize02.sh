#!/bin/sh
set -e

mkdir -p "$1/etc/NetworkManager/conf.d"
printf "[keyfile]\nunmanaged-devices=none\n" \
    > "$1/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"
