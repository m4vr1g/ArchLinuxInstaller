#!/bin/bash

script_id="0001"

. common.sh

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
		
	explain_actual_command "parted -lm 2> /dev/null"
	while read line
	do
		explain_actual_output "$line"
		
		# Ignore empty lines
		if [ -z "$line" ]
		then
			filtered_echo $ALL "DEBUG: Skipping empty line"
			continue
		fi		

		# New disk definition
		if [[ "BYT;" == "$line" ]]
		then
			filtered_echo $ALL "DEBUG: New disk"
			unset -v current_disk
			filtered_echo $ALL "DEBUG: Unset current_disk"
			continue
		fi
		
		# If current_disk is not set the next line should be a disk definition
		if [ -z "$current_disk" ]
		then 
			filtered_echo $ALL "DEBUG: New disk definition"
			current_disk="$(echo "$line" | cut -d":" -f1)"
			filtered_echo $DEBUG "DEBUG: cd: $current_disk"
			continue
		fi
		
		# Get esp partitions
		# Use grep with PERL regex (for lookaround)
		#match=$(echo '$line' | sed -r 's/$match_pat/\1/g')
		match=$(echo "${line}" | grep -P "${match_pat}")
		filtered_echo $DEBUG "$match"
		if [[ ! -z "$match" ]]
		then
			filtered_echo $DEBUG "DEBUG: Matched"
			if [[ "$line" =~ $capuring_pat ]]
			then
				next_index=${#disks[@]}
				
				part="${BASH_REMATCH[1]}"
				disks+=("$current_disk|$part")
				
				message="\t$next_index:\t$current_disk\t$part"
				(( next_index == 0 )) && message="$message\t(DEFAULT)"				
				
				filtered_echo $VERBOSE $message
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
	filtered_echo $DEBUG "${selected_disk} selected"
	
	# Return selected disk (subshell)
	echo $selected_disk 
}

explain

filtered_echo $VERBOSE "Method: "
filtered_echo $VERBOSE "\t0:\tefibootmgr\t(Default)"
filtered_echo $VERBOSE "\t1:\tstartup.nsh"
read -p "> " method

explain "0001"
filtered_echo $VERBOSE "Select root partition:"
root_partition_pat="[0-9]*:[^:]*:[^:]*:[^:]*:[^:]*:((?!esp|swap).)*$"
root_partition_capture_pat="^([0-9]*):"
root="$(parse_parted $root_partition_pat $root_partition_capture_pat)"
root="${root//|}"
root="${root//\/dev}"

explain "0002"
# Get partuuid for selected root partition
root_part_uuid=$(ls -lha /dev/disk/by-partuuid | grep ".*${root}$" | cut -d" " -f10)
explain_actual_command "ls -lha /dev/disk/by-partuuid | grep \".*${root}$\" | cut -d\" \" -f10"
explain_actual_output "$root_part_uuid"

if [ "$method" -eq 1 ]
then
	explain "0003"
	filtered_echo $VERBOSE "Select EFI System partition:"
	esp_partition_pat="([0-9]*):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*esp[^:]*"
	esp_partition_capture_pat="^([0-9]*):"

	esp="$(parse_parted $esp_partition_pat $esp_partition_capture_pat)"
	
	disk="$(echo $esp | cut -d"|" -f1)"
	part="$(echo $esp | cut -d"|" -f2)"
	
	# == EFI boot label ==
	explain "0004"
	filtered_echo $VERBOSE "Efi Label (Default: Arch Linux): "
	read -p "> " label

	[ -z "$label" ] && label="Arch Linux"

	# Actual add command
	explain "0005"
	explain_actual_command "efibootmgr --disk \"$disk\" --part \"$part\" --create --label \"$label\" --loader /vmlinuz-linux --unicode \"root=PARTUUID=${root_part_uuid} rw initrd=\initramfs-linux.img\" --verbose"
	#efibootmgr_output=$(efibootmgr --disk "$disk" --part "$part" --create --label "$label" --loader /vmlinuz-linux --unicode "root=PARTUUID=${root_part_uuid} rw initrd=\initramfs-linux.img" --verbose)
	explain_actual_output $efibootmgr_output
	
else
	# startup.nsh
	explain "0006"
	explain_actual_command "echo -e \"vmlinuz-linux --unicode root=PARTUUID=${root_part_uuid} rw initrd=\initramfs-linux.img\" > /mnt/boot/startup.nsh"
	# echo -e "vmlinuz-linux --unicode root=PARTUUID=${root_part_uuid} rw initrd=\initramfs-linux.img" > /mnt/boot/startup.nsh
	
fi
