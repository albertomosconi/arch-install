# Arch Linux install script

A simple script that sets up a base arch installation.

**Run this after partitioning the disk. Make sure the partition names match.**

## Usage
Download the script
```
curl https://raw.githubusercontent.com/albertomosconi/arch-install/main/download.sh | bash
```
Then edit the `uefi.conf` to customize your install and finally run the script
```
./base-uefi.sh
```
