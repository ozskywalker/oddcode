#!/bin/sh
# Disables IPv6 on all interfaces

IFS=$'\n'
net=`networksetup -listallnetworkservices | grep -v asterisk`
for i in $net
do
networksetup -setv6off "$i"
echo "$i" IPv6 is Off
done

exit 0