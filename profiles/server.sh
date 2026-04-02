#!/bin/sh

. "$(dirname "$0")/minimal.sh"

PACKAGES="$PACKAGES,\
openssh-server,ufw,fail2ban,rsync,htop,tmux,unattended-upgrades"
