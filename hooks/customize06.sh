#!/bin/sh
set -e

chroot "$1" systemctl enable \
    NetworkManager \
    chrony \
    gdm3 2>/dev/null || true

rm -f "$1/usr/sbin/policy-rc.d"
