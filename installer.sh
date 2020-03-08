#!/bin/bash

script_id="0000"

. common.sh

# == Keyboard layout
filtered_echo $VERBOSE "Enter keyboard layout:"
read -p "> " keyboard_layout

loadkeys keyboard_layout

# == Check if UEFI mode enabled
[ -d /sys/firmware/efi/efivars ] && EFIMODE=1

ping -c 1 www.google.be > /dev/null && INTERNET=1

if  [ -z "$INTERNET" ]
then
	. network.sh
fi

# TODO: Call fdisk a first time to make sure GTK disklabel type
# g # create guided partition table
# TODO: Use "Expect" (?)
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
  o # clear the in memory partition table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
  +512M # 512 MB boot parttion
  t # type
	# default (last partition) 
  1	# EFI System
  n # new partition
  2 # partion number 2
    # default, start immediately after preceding partition
  -18G # -size of swap
  t # type
  	# default (last partition) 
  24# Linux root (x86-64)
  n # new partition
  3 # partition number 3
	# default
	# rest of the disk
  t # type
  	# default (last partition) 
  19# Linux Swap 
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkswap /dev/sda3
swapon /dev/sda3

mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

pacstrap /mnt base linux linux-firmware

pacstrap /mnt dhcp wpa_supplicant e2fsprogs vim man-db man-pages texinfo wget

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt
ln -sf /usr/share/zoneinfo/Europe/Brussels /etc/localtime
hwclock --systohc

# uncomment LANG=en_US.UTF-8 in /etc/locale.gen

locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "ARCHY" > /etc/hostname

echo "127.0.0.1	localhost" >> /etc/hosts
echo "::1		localhost" >> /etc/hosts
echo "127.0.1.1	ARCHY.local	ARCHY" >> /etc/hosts

passwd

. add_to_efistub.sh

