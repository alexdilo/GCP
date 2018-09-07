#!/bin/bash


CMDS=`cat <<END
df -h
free -h
uptime;uptime
df -a --inodes
systemctl status -l docker
journalctl -u docker
journalctl -u docker-monitor.service
systemctl status -l kubelet
journalctl -u kubelet
journalctl -u kubelet-monitor.service
ip addr
iptables -L
mount
ip route list table all
END
`

echo -e "\n\n""============================================" 
echo -e "============================================" 
echo -e "     @@@@@@>>>DEBUG SSH SCRIPT<<<@@@@@@"   
echo -e "$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")"
echo -e "============================================"
echo -e "============================================\n\n" 




while read line
do
echo -e "\n\n""============================================" 
echo -e "============================================"
echo -e $line  
echo -e "$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")"
echo -e "============================================" 
echo -e "============================================\n\n" 
sudo bash -c "$line" 
done <<< "$CMDS"
