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
	
	read -p "DHCP? yes(default)/no:" response
	if [ -z "$response" ] \
		|| [[ "y" == "$response" ]] \
		|| [[ "yes" == "$response" ]]
	then
		echo "Running dhcpcd"
		dhcpcd enp0s3
	elif 
		read -p "Static? yes(default)/no:" response
		if [ -z "$response" ] \
			|| [[ "y" == "$response" ]] \
			|| [[ "yes" == "$response" ]]
		then
			# TODO: This :)
		fi
	fi
	
	sleep 5

	echo -ne "Ping IPv4"
	ping -4 -I enp0s3 www.google.com -c1 > /dev/null
	if [ $? -ne 0 ] ; then echo " failed"; else echo " success"; fi  
	echo -ne "Ping IPv6"
	ping -6 -I enp0s3 www.google.com -c1 > /dev/null
	if [ $? -ne 0 ] ; then echo " failed"; else echo " success"; fi

	# TODO: ping interface gateways to check connectivity without internet.
fi

read -p "Enable WLAN yes(default)/no:" response
if [ -z "$response" ] \
	|| [[ "y" == "$response" ]] \
	|| [[ "yes" == "$response" ]]
then
	# TODO: scan for interfaces and ask for each of them.
	echo "Enabling interface"
	ip link set wlan0 up
	
	# Create config file:
	echo "ctrl_interface=/run/wpa_supplicant" > /etc/wpa_supplicant/wpa_supplicant.conf
	echo "update_config=1" >> /etc/wpa_supplicant/wpa_supplicant.conf

	# Start wpa_supplicant
	wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

	wpa_cli -i wlan0 scan
	wpa_cli -i wlan0 scan_results
	newNetwork=$(wpa_cli -i wlan0 add_network)
	
	read -p "SSID:" ssid
	read -p "PSK:" psk

	wpa_cli -i wlan0 set_network $newNetwork ssid $ssid
	wpa_cli -i wlan0 set_network $newNetwork psk $psk
	
	wpa_cli -i wlan0 enable_network 0
	wpa_cli -i wlan0 save_config
	
	read -p "DHCP? yes(default)/no:" response
	if [ -z "$response" ] \
		|| [[ "y" == "$response" ]] \
		|| [[ "yes" == "$response" ]]
	then
		echo "Running dhcpcd"
		dhcpcd wlan0
	elif 
		read -p "Static? yes(default)/no:" response
		if [ -z "$response" ] \
			|| [[ "y" == "$response" ]] \
			|| [[ "yes" == "$response" ]]
		then
			# TODO: This :)
		fi
	fi
	
	sleep 5

	echo -ne "Ping IPv4"
	ping -4 -I wlan0 www.google.com -c1 > /dev/null
	if [ $? -ne 0 ] ; then echo " failed"; else echo " success"; fi  
	echo -ne "Ping IPv6"
	ping -6 -I wlan0 www.google.com -c1 > /dev/null
	if [ $? -ne 0 ] ; then echo " failed"; else echo " success"; fi

	# TODO: ping interface gateways to check connectivity without internet.
fi