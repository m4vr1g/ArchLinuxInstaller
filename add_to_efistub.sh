#!/bin/bash

NONE=0
VERBOSE=1
DEBUG=2
INFO=3
ALL=10

verbose=$VERBOSE

exec 3>&1

verbose_echo () {
	(( $verbose >= $1 )) && echo -e "$2" >&3
}

parse_parted () {
	# == GET Partition(s) ==
	# Parted machine readable output:
	# BYT;
	# /dev/sda:53.7GB:scsi:512:512:gpt:ATA VBOX HARDDISK:;
	# 1:1049kB:274MB:273MB:fat32::boot, esp;
	disks=()

	current_disk="";
	
	match_pat=$1
	capuring_pat=$2
	[ -z "$capuring_pat" ] && capuring_pat="$match_pat"
	
	while read line
	do
		# Ignore empty lines
		if [ -z "$line" ]
		then
			verbose_echo $ALL "DEBUG: Skipping empty line"
			continue
		fi		

		# New disk definition
		if [[ "BYT;" == "$line" ]]
		then
			verbose_echo $ALL "DEBUG: New disk"
			unset -v current_disk
			verbose_echo $ALL "DEBUG: Unset current_disk"
			continue
		fi
		
		# If current_disk is not set the next line should be a disk definition
		if [ -z "$current_disk" ]
		then 
			verbose_echo $ALL "DEBUG: New disk definition"
			current_disk="$(echo "$line" | cut -d":" -f1)"
			verbose_echo $DEBUG "DEBUG: cd: $current_disk"
			continue
		fi
		
		# Get esp partitions
		# Use grep with PERL regex (for lookaround)
		#match=$(echo '$line' | sed -r 's/$match_pat/\1/g')
		match=$(echo "${line}" | grep -P "${match_pat}")
		verbose_echo $DEBUG "$match"
		if [[ ! -z "$match" ]]
		then
			verbose_echo $DEBUG "DEBUG: Matched"
			if [[ "$line" =~ $capuring_pat ]]
			then
				next_index=${#disks[@]}
				
				part="${BASH_REMATCH[1]}"
				disks+=("$current_disk|$part")
				
				message="\t$next_index:\t$current_disk\t$part"
				(( next_index == 0 )) && message="$message\t(DEFAULT)"				
				
				verbose_echo $VERBOSE $message
			fi
			continue
		fi
	done < <(parted -lm 2> /dev/null | sed 's///g') 
	# Ignore stderr
	# Remove strange ctrl+M chars in between disks

	# == Get users selection ==
	read -p "> " selected_disk_index
	[ -z "$selected_disk_index" ] && selected_disk_index=0
	# TODO: Check if valid integer/index
	selected_disk=${disks[$selected_disk_index]}
	verbose_echo $DEBUG "${selected_disk} selected"
	
	# Return selected disk (subshell)
	echo $selected_disk 
}


verbose_echo $VERBOSE "Select EFI System partition:"
esp_partition_pat="([0-9]*):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*esp[^:]*"
esp_partition_capture_pat="^([0-9]*):"
esp="$(parse_parted $esp_partition_pat $esp_partition_capture_pat)"


verbose_echo $VERBOSE "Select root partition:"
root_partition_pat="[0-9]*:[^:]*:[^:]*:[^:]*:[^:]*:((?!esp|swap).)*$"
root_partition_capture_pat="^([0-9]*):"
root="$(parse_parted $root_partition_pat $root_partition_capture_pat)"
root="${root//|}"
root="${root//\/dev}"

# Get partuuid for selected root partition
root_part_uuid=$(ls -lha /dev/disk/by-partuuid | grep ".*${root}$" | cut -d" " -f10)

disk="$(echo $esp | cut -d"|" -f1)"
part="$(echo $esp | cut -d"|" -f2)"
# == EFI boot label ==
verbose_echo $VERBOSE "Efi Label (Default: Arch Linux): "
read -p "> " label

[ -z "$label" ] && label="Arch Linux"

# Actual add command
efibootmgr --disk "$disk" --part "$part" --create --label "$label" --loader /vmlinuz-linux --unicode "root=PARTUUID=${root_part_uuid} rw initrd=\initramfs-linux.img" --verbose
