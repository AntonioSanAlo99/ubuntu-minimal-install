#!/bin/sh
set -e

echo "debconf debconf/priority select critical" | chroot "$1" debconf-set-selections
echo "debconf debconf/frontend select Noninteractive" | chroot "$1" debconf-set-selections

printf "#!/bin/sh\nexit 101\n" > "$1/usr/sbin/policy-rc.d"
chmod +x "$1/usr/sbin/policy-rc.d"
