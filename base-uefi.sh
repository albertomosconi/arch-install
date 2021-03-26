#!/bin/sh

CONFIG_FILE="uefi.conf"
. "./$CONFIG_FILE"

printf "\n" | timedatectl set-ntp true

BOOT_PARTITION=""
ROOT_PARTITION=""
if [ -n "$(echo $DEVICE | grep "^/dev/[a-z]d[a-z]")" ]; then
    BOOT_PARTITION="${DEVICE}1"
    ROOT_PARTITION="${DEVICE}2"
elif [ -n "$(echo $DEVICE | grep "^dev/nvme")" ]; then
    BOOT_PARTITION="${DEVICE}p1"
    ROOT_PARTITION="${DEVICE}p2"
fi

printf "n\n\n\n+300M\nef00\nn\n\n\n\n\nw\ny\n" | gdisk $DEVICE

mkfs.fat -F32 $BOOT_PARTITION
mkfs.ext4 $ROOT_PARTITION

mount $ROOT_PARTITION /mnt
mkdir -p /mnt/boot/efi
mount $BOOT_PARTITION /mnt/boot/efi

pacstrap /mnt base linux-zen linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab

# setup timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
arch-chroot /mnt hwclock --systohc

# localization
sed -i '177s/.//' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LOCALE" >> /mnt/etc/locale.conf 
echo "KEYMAP=$KEYMAP" >> /mnt/etc/vconsole.conf

# network configuration
echo "$HOSTNAME" >> /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.0.1 $HOSTNAME.localdomain $HOSTNAME" >> /mnt/etc/hosts

# set root password
# echo root:$ROOT_PASS | chpasswd
printf "$ROOT_PASS\n$ROOT_PASS" | arch-chroot /mnt passwd

# install packages
arch-chroot /mnt pacman -S --noconfirm grub efibootmgr git networkmanager network-manager-applet dialog wpa_supplicant reflector base-devel linux-headers dosfstools mtools xdg-user-dirs xdg-utils cups cups-runit alsa-utils pulseaudio neovim zsh dash neofetch

# optional gpu packages
# pacman -S --noconfirm xf86-video-amdgpu
# pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

# install grub bootloader
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# enable services
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable cups
arch-chroot /mnt systemctl enable reflector.timer
arch-chroot /mnt systemctl enable fstrim.timer

# add new user
arch-chroot /mnt useradd -m $USERNAME
# echo $USERNAME:$USER_PASS | chpasswd
printf "$USER_PASS\n$USER_PASS" | arch-chroot /mnt passwd $USERNAME
echo "$USERNAME ALL=(ALL) ALL" >> /mnt/etc/sudoers.d/$USERNAME

arch-chroot /mnt chsh -s /bin/zsh $USERNAME

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

arch-chroot /mnt chown -R $USERNAME:$USERNAME /home/$USERNAME/

arch-chroot /mnt ln -sfT dash /usr/bin/sh

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