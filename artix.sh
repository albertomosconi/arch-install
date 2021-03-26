#!/bin/sh

CONFIG_FILE="uefi.conf"
. "./$CONFIG_FILE"

# printf "\n" | timedatectl set-ntp true
# printf "n\n\n\n+300M\nef00\nn\n\n\n\n\nw\ny\n" | gdisk $DEVICE
printf "n\np\n\n\n+300M\nt\nef\nn\np\n\n\n\nw\n" | fdisk $DEVICE

mkfs.fat -F32 $DEVICE\1
mkfs.ext4 $DEVICE\2

mount $DEVICE\2 /mnt
mkdir -p /mnt/boot/efi
mount $DEVICE\1 /mnt/boot/efi

basestrap /mnt base base-devel runit elogind-runit linux-zen linux-firmware

fstabgen -U /mnt >> /mnt/etc/fstab

# setup timezone
artix-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
artix-chroot /mnt hwclock --systohc

# localization
sed -i '177s/.//' /mnt/etc/locale.gen
artix-chroot /mnt locale-gen
echo "LANG=$LOCALE" >> /mnt/etc/locale.conf 
echo "KEYMAP=$KEYMAP" >> /mnt/etc/vconsole.conf

# network configuration
echo "$HOSTNAME" >> /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.0.1 $HOSTNAME.localdomain $HOSTNAME" >> /mnt/etc/hosts

# set root password
printf "$ROOT_PASS\n$ROOT_PASS" | artix-chroot /mnt passwd

# install packages
artix-chroot /mnt pacman -S --noconfirm grub efibootmgr git networkmanager networkmanager-runit network-manager-applet dialog wpa_supplicant reflector base-devel linux-headers dosfstools mtools xdg-user-dirs xdg-utils cups alsa-utils pulseaudio neovim zsh dash neofetch

# optional gpu packages
# pacman -S --noconfirm xf86-video-amdgpu
# pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

# install grub bootloader
artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

artix-chroot /mnt ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default

# add new user
artix-chroot /mnt useradd -m $USERNAME
# echo $USERNAME:$USER_PASS | chpasswd
printf "$USER_PASS\n$USER_PASS" | artix-chroot /mnt passwd $USERNAME
echo "$USERNAME ALL=(ALL) ALL" >> /mnt/etc/sudoers.d/$USERNAME

artix-chroot /mnt chsh -s /bin/zsh $USERNAME

curl -O https://raw.githubusercontent.com/albertomosconi/dotfiles/master/.zprofile
curl -O https://raw.githubusercontent.com/albertomosconi/dotfiles/master/.config/aliasrc
curl -O https://raw.githubusercontent.com/albertomosconi/dotfiles/master/.config/zsh/.zshrc

mv .zprofile /mnt/home/$USERNAME/
ln /mnt/home/$USERNAME/.zprofile /mnt/home/$USERNAME/.profile

mkdir -p /mnt/home/$USERNAME/.local/bin
mkdir -p /mnt/home/$USERNAME/.config/zsh

mv aliasrc /mnt/home/$USERNAME/.config/
mv .zshrc /mnt/home/$USERNAME/.config/zsh/

rm /mnt/home/$USERNAME/.bash*

artix-chroot /mnt chown -R $USERNAME:$USERNAME /home/$USERNAME/

artix-chroot /mnt ln -sfT dash /usr/bin/sh

echo "[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = bash

[Action]
Description = Re-pointing /bin/sh symlink to dash...
When = PostTransaction
Exec = /usr/bin/ln -sfT dash /usr/bin/sh
Depends = dash" > /mnt/usr/share/libalpm/hooks/bash-update.hook

umount -a
echo -e "\e[1;32mRebooting in 5..4..3..2..1\e[0m"
sleep 5
reboot