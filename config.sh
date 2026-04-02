#!/bin/sh

# Mirror and suite
MIRROR="http://archive.ubuntu.com/ubuntu/"
SUITE="questing"
COMPONENTS="main,restricted,universe,multiverse"

# Target mount point
TARGET="/mnt/ubuntu"

# System configuration
HOSTNAME="ubuntu"
TIMEZONE="Europe/Madrid"
LOCALE="es_ES.UTF-8"
KEYMAP="es"

# Hook directory
HOOK_DIR="$(dirname "$0")/hooks"
