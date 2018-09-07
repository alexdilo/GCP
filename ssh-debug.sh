#!/bin/bash
##########################
##########################
#  GCLOUD COMMAND 
#  gcloud compute instances add-metadata [instance name] --metadata-from-file startup-script=ssh-debug.sh
##########################
##########################



CMDS=`cat <<END
iptables -nvL sshguard
netstat -tulp 
cat /proc/net/nf_conntrack | wc -l
ping -c 2 www.google.com
ping -c 2 www.amazon.com
dpkg -l | grep google 
df -h
free -h
systemctl list-units | grep google
systemctl status google-accounts-daemon
ps aux | grep [s]sh
service  sshd status
ps aux | grep [g]oogle
curl "http://metadata.google.internal/0.1/meta-data/attributes/sshKeys" -H "Metadata-Flavor: Google"
curl "http://metadata.google.internal/0.1/meta-data/attributes/ssh-keys" -H "Metadata-Flavor: Google"
tail -n 40 /var/log/secure
tail -n 40 /var/log/auth.log
tail -n 40 /var/log/messages
cat /var/log/dpkg.log* | grep -i google
tail -n 50  /var/log/cloud-init.log 
find / -name authorized_keys
find / -name authorized_keys -exec cat {} +
find / -name ssh_config
find / -name ssh_config  -exec cat {} +
cat /etc/passwd 
END
`

echo -e "\n\n""============================================" > /dev/ttyS0
echo -e "============================================" > /dev/ttyS0
echo -e "     @@@@@@>>>DEBUG SSH SCRIPT<<<@@@@@@"  > /dev/ttyS0
echo -e "============================================" > /dev/ttyS0
echo -e "============================================\n\n" > /dev/ttyS0




while read line
do
echo -e "\n\n""============================================" > /dev/ttyS0
echo -e "============================================" > /dev/ttyS0
echo -e $line > /dev/ttyS0
echo -e "============================================" > /dev/ttyS0
echo -e "============================================\n\n" > /dev/ttyS0
bash -c "$line" > /dev/ttyS0
done <<< "$CMDS"
