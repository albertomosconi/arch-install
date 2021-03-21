#!/bin/sh

CONFIG_FILE="uefi.conf"

. "./$CONFIG_FILE"

# setup timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# localization
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" >> /etc/locale.conf 
echo "KEYMAP=$KEYMAP" >> /etc/vconsole.conf

# network configuration
echo "$HOSTNAME" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.0.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# set root password
echo root:$ROOT_PASS | chpasswd

# install packages
pacman -S --noconfirm grub efibootmgr networkmanager network-manager-applet dialog wpa_supplicant reflector base-devel linux-headers dosfstools mtools xdg-user-dirs xdg-utils cups alsa-utils pulseaudio neovim firewalld

# optional gpu packages
# pacman -S --noconfirm xf86-video-amdgpu
# pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

# install grub bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

# enable services
systemctl enable NetworkManager
systemctl enable cups
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable firewalld

# add new user
useradd -m $USERNAME
echo $USERNAME:$USER_PASS | chpasswd
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers.d/$USERNAME

# done
echo -e "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
