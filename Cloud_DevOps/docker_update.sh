#!/bin/sh
echo "[+] Before..."
docker images && df -h

echo "[+] During..."
docker images |grep -v REPOSITORY |awk '{print $1 ":" $2}' |xargs -L1 docker pull && docker rmi $(docker images --filter "dangling=true" -q --no-trunc)

echo "[+] After..."
docker images && df -h
