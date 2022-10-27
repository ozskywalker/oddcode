#!/bin/bash
# Checks Ubuntu/Linux for pending package updates, and notifies you via Ntfy.sh
#

if [ -f /etc/lsb-release ]; then
    TYPE="UBUNTU"
elif [ -f /etc/debian_version ]; then
    TYPE="DEBIAN"
fi

case ${TYPE} in
    "UBUNTU")
        VERSION=`grep "DISTRIB_CODENAME" /etc/lsb-release | awk -F = '{ print $2 }'`
        ;;
    "DEBIAN")
        VERSION="Debian `cat /etc/debian_version`"
        ;;
esac

HOSTNAME=`hostname`
SUBJECT="Updates for host ${HOSTNAME}"
DATE=`date +%d.%m.%Y`
AVAIL_UPD=`apt-get -s upgrade | awk '/[0-9]+ upgraded,/ {print $1}'`

function ntfyupdates {
    echo -e "--- Updates for host: ${HOSTNAME} ---"
    echo -e "Date: ${DATE} \n\n"

    echo -n "Total updates available: "
    apt-get -s upgrade | awk '/[0-9]+ upgraded,/ {print $1}'
    echo -e "  "

    echo -n "Packages: "
    apt-get -s upgrade | grep "Inst" | awk '{ print $2 }' | paste -sd ","
}

if [[ ${AVAIL_UPD} == 0 ]]; then
    sleep 1
else
    ntfyupdates | curl https://ntfy.sh/<putyourtopicnamehere> -d @-
fi