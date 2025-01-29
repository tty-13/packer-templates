#!/bin/sh

HERE="$(dirname "$(readlink -f "$0")")"
CONF=$HERE/cdrom/conf/config.xml
NOW="$(date +%s.%N | cut -b1-15)"

# Make sure there are no leftovers from a previous build
rm -f $HERE/packerkey*
rm -f packerpwd.tmp
cp $HERE/config.template $HERE/cdrom/conf/config.xml

# Genereate new temporary credentials
ssh-keygen -q -t ed25519 -N '' -C packer -f $HERE/packerkey
echo -n $(cat $HERE/packerkey.pub) | base64 -w0 > $HERE/packerkey.base64
htpasswd -bnBC 10 "" $(pwgen -CnB1 32) | tr -d ':\n' > $HERE/packerpwd.tmp

# timestamp the config file and expire the packer user the next day
sed -e "s|<time>.*</time>|<time>$NOW</time>|" -i $CONF
sed -e "s|<expires>.*</expires>|<expires>$(date +%D -d "+1 day")</expires>|" -i $CONF

# Set packer password and ssh authorized key
sed -e "s|<password>.*</password>|<password>$(cat $HERE/packerpwd.tmp)</password>|" -i $CONF
sed -e "s|<authorizedkeys>.*</authorizedkeys>|<authorizedkeys>$(cat $HERE/packerkey.base64)</authorizedkeys>|" -i $CONF

# build the VM
packer build -var-file="$HERE/../proxmox_api_credentials.pkr.hcl" -var-file="$HERE/credentials.pkr.hcl" $HERE/opnsense.pkr.hcl

# Remove temporary credentials
rm -f $HERE/packerkey*
rm -f $HERE/packerpwd.tmp