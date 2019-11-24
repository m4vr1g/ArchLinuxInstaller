#!/bin/bash

# Bring up lan interface
# TODO: Check if LAN is already connceted before.

read -p "Enable LAN yes(default)/no:" response
if [ -z "$response" ] \
	|| [[ "y" == "$response" ]] \
	|| [[ "yes" == "$response" ]]
then
	# TODO: scan for interfaces and ask for each of them.
	echo "Enabling interface"
	ip link set enp0s3 up
	echo "Running dhcpcd"
	dhcpcd enp0s3
	
	sleep 5

	echo -ne "Ping IPv4"
	ping -4 -I enp0s3 www.google.com -c1 > /dev/null
	if [ $? -ne 0 ] ; then echo " failed"; else echo " success"; fi  
	echo -ne "Ping IPv6"
	ping -6 -I enp0s3 www.google.com -c1 > /dev/null
	if [ $? -ne 0 ] ; then echo " failed"; else echo " success"; fi

	# TODO: ping interface gateways to check connectivity without internet.
fi

read -p "Enable SSH server? [yes(default)/no]:" response
if [ -z "$response" ] \
	|| [[ "y" == "$response" ]] \
       	|| [[ "yes" == "$response" ]]
then
	# Sync pacman database
	echo -ne "Updating pacman database"
	pacman -Syy > /dev/null
	echo "  DONE"
	# TODO: check if update worked.

	# Check if openssh is installed.
	echo -ne "Installing openssh (if needed)"
	pacman -Qi openssh > /dev/null
	# Instal openssh when not found.
	[ $? -ne 0 ] && pacman -S openssh > /dev/null
	echo " DONE"

	# == Enable root login (temp)
	# Check if already enabled.
	root_login_enabled=$(grep -cE "^PermitRootLogin yes$" /etc/ssh/sshd_config)
	echo $root_login_enabled
	if [ "$root_login_enabled" -eq 0 ]
	then
		read -p "Permit root login? [yes(default)/no]:" response
		if [ -z "$response" ] \
			|| [[ "y" == "$response" ]] \
			|| [[ "yes" == "$response" ]]
		then
			# Disable all PermitRootLogin options.
			sed -i 's/^PermitRootLogin/#PermitRootLogin/g' /etc/ssh/sshd_config
			
			contains_yes_option=$(grep -cE "^#PermitRootLogin yes$" /etc/ssh/sshd_config)
			if [ "$contains_yes_option" -ne 0 ]
			then
				echo "Enabling existing PermitRootLogin line"
				# Enable the existing entry.
				sed -i '0,/#PermitRootLogin yes/{s/#PermitRootLogin/PermitRootLogin/}' /etc/ssh/sshd_config
			else
				echo "Add new PermitRootLogin line to config file"
				# Add it to the config file.
				# TODO: Check if I can just add it to the bottom of the config :s
				echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
			fi
		fi	
	else
		echo "!!! PermitRootLogin is already enabled."
	fi
	
	# Start SSH
	# TODO: check if already started ==> restart
	systemctl start sshd
fi

