#!/bin/sh
set -e

chroot "$1" dracut --force
