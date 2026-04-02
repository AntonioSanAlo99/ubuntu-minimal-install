#!/bin/sh
set -e

echo "$HOSTNAME" > "$1/etc/hostname"

cat > "$1/etc/default/keyboard" << EOF
XKBMODEL="pc105"
XKBLAYOUT="${KEYMAP}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
