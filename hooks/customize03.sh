#!/bin/sh
set -e

chroot "$1" /bin/sh -c "
    sed -i \"s/^# *${LOCALE}/${LOCALE}/\" /etc/locale.gen
    locale-gen
    update-locale LANG=${LOCALE}
"
