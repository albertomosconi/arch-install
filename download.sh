#!/bin/sh

rm -f base-uefi.sh
rm -f artix.sh
rm -f uefi.conf

curl -O https://raw.githubusercontent.com/albertomosconi/arch-install/main/base-uefi.sh
curl -O https://raw.githubusercontent.com/albertomosconi/arch-install/main/artix.sh
curl -O https://raw.githubusercontent.com/albertomosconi/arch-install/main/uefi.conf

chmod +x base-uefi.sh
chmod +x artix.sh