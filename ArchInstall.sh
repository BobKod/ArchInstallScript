#!/bin/sh

clear

disk="/dev/sda"
root_pswd="0000"
user_name="user"
user_pswd="1111"

wipefs -a $disk
parted $disk mklabel gpt mkpart EFI 1049kB 106MB set 1 boot on mkpart ArchLinux 106MB 100%
mkfs.vfat -n EFI $disk"1"
mkfs.btrfs -f -L ArchLinux $disk"2"

mount $disk"2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o noatime,compress=zstd:3,discard=async,subvol=@ $disk"2" /mnt
mount --mkdir -o noatime $disk"1" /mnt/boot/efi
mount --mkdir -o noatime,compress=zstd:3,discard,subvol=@home $disk"2" /mnt/home

pacstrap /mnt base linux linux-firmware btrfs-progs intel-ucode nano grub networkmanager sudo htop neofetch
#efibootmgr

genfstab -U /mnt | sed "s/subvolid=[[:digit:]]\+,//" > /mnt/etc/fstab

arch-chroot /mnt grub-install --removable
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

arch-chroot /mnt sh -c "echo root:$root_pswd | chpasswd; useradd -mG wheel $user_name; echo $user_name:$user_pswd | chpasswd"
echo -e "\n%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers

arch-chroot /mnt systemctl enable NetworkManager.service
echo "My-PC" > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1	localhost" >> /mnt/etc/hosts

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
arch-chroot /mnt hwclock --systohc
echo -e "\nen_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=ru_RU.UTF-8" > /mnt/etc/locale.conf
echo "FONT=cyr-sun16" > /mnt/etc/vconsole.conf

echo -e "\n\n=======Installation completed!======="

