#!/bin/sh

CONFIG_FILE="uefi.conf"
. "./$CONFIG_FILE"

mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

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
arch-chroot /mnt pacman -S --noconfirm grub efibootmgr git networkmanager network-manager-applet dialog wpa_supplicant reflector base-devel linux-headers dosfstools mtools xdg-user-dirs xdg-utils cups alsa-utils pulseaudio neovim firewalld zsh

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
arch-chroot /mnt systemctl enable firewalld

# add new user
arch-chroot /mnt useradd -m $USERNAME
# echo $USERNAME:$USER_PASS | chpasswd
printf "$USER_PASS\n$USER_PASS" | arch-chroot /mnt passwd $USERNAME
echo "$USERNAME ALL=(ALL) ALL" >> /mnt/etc/sudoers.d/$USERNAME

chsh -s /mnt/bin/zsh $USERNAME

# done
# echo -e "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
umount -a
echo "Rebooting in 5..4..3..2..1"
sleep 5
reboot