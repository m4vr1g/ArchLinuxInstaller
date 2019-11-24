#!/bin/bash

# === Output Controlling ===
NONE=0
VERBOSE=1
DEBUG=2
INFO=3
ALL=10

# Default level is VERBOSE
verbose=$VERBOSE
explain_enabled=1

# Create copy of current stdin so echo will alway output to user stdin
exec 3>&1

# Actual echo function.
filtered_echo () {
	(( $verbose >= $1 )) && echo -e "$2" >&3
}

explain () {
	if [ "$explain_enabled" -eq 0 ]
	then 
		echo "explain not enabled" >&3
		exit
	fi
	if [[ -z "$script_id" ]] 
	then
		echo "No script_id set" >&3
		exit
	fi

	grep "^${script_id}:${1}:.*" explanation.txt \
	| sed -r "s/^${script_id}:${1}:(.*)/\1/" \
	| sed "s/<b>/\\\\e[1m/g; \
		   s/<\/b>/\\\\e[22m/g; \
		   s/<u>/\\\\e[4m/g; \
		   s/<\/u>/\\\\e[22m/g; \
		   s/<command>/\\\\e[34m/g; \
		   s/<\/command>/\\\\e[39m/g" \
	| while read -r i; do echo -e "$i\e[0m" >&3; done
}

explain_actual_command () {
	[ "$explain_enabled" -eq 1 ] && echo -ne "\nACTUAL COMMAND: \e[31m$1\e[39m\n\n" >&3
}
explain_actual_output () {
	[ "$explain_enabled" -eq 1 ] && echo -ne "\nACTUAL OUTPUT: \e[33m$1\e[39m\n\n" >&3
}

# === End ===
