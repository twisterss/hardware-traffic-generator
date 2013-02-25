#!/bin/bash
# Dumps debug registers of the design

echo "Current status: "
csbus 0x80000
echo "Current action requested: "
csbus 0x80004
if [[ "$1" != "" ]]
then
	csbus 0x80004 $1
	echo "Requested action 0x$1" 
fi
