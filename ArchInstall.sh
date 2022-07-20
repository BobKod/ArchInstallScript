#!/bin/sh

clear

disk="/dev/sda"
root_pswd="0000"
user_name="papa"
user_pswd="1111"

wipefs -a $disk
parted $disk mklabel gpt mkpart EFI 1049kB 525MB set 1 boot on mkpart ArchLinux 525MB 100%
mkfs.vfat -n EFI $disk"1"
mkfs.btrfs -f -L ArchLinux $disk"2"

mount $disk"2" /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
cd
umount /mnt

mount -o noatime,subvol=@ $disk"2" /mnt
cd /mnt
mkdir -p {boot/efi,home}
mount -o noatime $disk"1" boot/efi
mount -o noatime,subvol=@home $disk"2" home

pacstrap /mnt base linux linux-firmware btrfs-progs intel-ucode nano grub efibootmgr networkmanager sudo htop neofetch

genfstab -U /mnt > etc/fstab

arch-chroot /mnt grub-install
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

