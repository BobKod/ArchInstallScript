#!/bin/zsh

select_disk()
{
    disks=()
    for device in $(lsblk -prndo NAME); do
        disk_size=$(lsblk -prndo SIZE $device)
        disks+=($device $disk_size)
    done
    local disk
    local result
    disk=$(dialog --title "Disc selection" --stdout --menu "Select a disk from the list to install ArchLinux" 16 32  1 ${disks[@]})
    result=$?
    echo $disk
    return $result
}

set_user_pswd()
{
    local pswd
    local result
    local warning
    locale confirm_pswd
    while :; do
        pswd=$(dialog --title "Setting a password for the user "$1 --stdout --insecure --passwordbox "${warning}enter password" 16 48)
        result=$?
        [ $result -eq 1 ] && exit $result
        [ ! -z $pswd ] && break
        warning="Empty Password!\n"
    done
    warning=""
    while :; do
        confirm_pswd=$(dialog --title "Setting a password for the user "$1 --stdout --insecure --passwordbox "${warning}Confirm the password" 16 48)
        result=$?
        [ $result -eq 1 ] && exit $result
        [ $confirm_pswd = $pswd ] && break
        warning="Passwords Do No Match!\n"
    done
    echo $pswd
    return $result
}

set_user_name()
{
    local user_name
    local result
    local warning
    while :; do
        user_name=$(dialog --title "Creating a user" --stdout --inputbox "${warning}Enter your new username" 16 48)
        result=$?
        [ $result -eq 1 ] && exit $result
        [[ $user_name =~ ^[A-Za-z]\W* ]] && break
        warning="Empty or incorrect username!\n"
        #break
    done
    echo $user_name
    return $result
}

clear
pacman -Sy dialog --noconfirm
if [ $? -ne 0 ]; then
    echo -e "package \"dialog\" is not installed"; exit
fi
[ -n "$(mount | grep /mnt)" ] && umount -R /mnt
dialog --title ArchInstall --ok-label "go" --msgbox \
"This is the Arch Linux installation script.\nNext, enter all the data necessary for installation.\nThe Cancel button aborts the script" 16 48

disk=$(select_disk); [ $? -eq 1 ] && exit
root_pswd=$(set_user_pswd "root"); [ $? -eq 1 ] && exit
user_name=$(set_user_name); [ $? -eq 1 ] && exit
user_pswd=$(set_user_pswd "$user_name"); [ $? -eq 1 ] && exit

clear
disk_s=${disk//\//\\\/}
part_efi=$(lsblk -prno NAME | sed -n "/$disk_s\w\w*/p" | sed -n 1p)
part_root=$(lsblk -prno NAME | sed -n "/$disk_s\w\w*/p" | sed -n 2p)
echo -e "g\nn\n\n\n+300M\nn\n\n\n\nw" | fdisk -w always -W always $disk
mkfs.vfat -n EFI $part_efi
mkfs.btrfs -f -L ArchLinux $part_root

mount $part_root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o noatime,compress=zstd:3,discard,subvol=@ $part_root /mnt
mount --mkdir -o noatime $part_efi /mnt/boot/efi
mount --mkdir -o noatime,compress=zstd:3,discard,subvol=@home $part_root /mnt/home

pacstrap /mnt base linux linux-firmware btrfs-progs intel-ucode grub networkmanager sudo nano htop neofetch
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

umount -R /mnt
dialog --infobox 'Installation completed!' 4 32
