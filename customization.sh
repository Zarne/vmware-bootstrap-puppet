#!/bin/bash

#Redirect stdout and stderr
exec >  /tmp/customization.log
exec 2> /tmp/customization.err

HOSTNAME=$1
IP=$2
SUBNET=$3
GATEWAY=$4
DNS=$5

rm -rf /etc/udev/rules.d/70-persistent-net.rules

echo $HOSTNAME > /etc/hostname
cat > /etc/network/interfaces <<EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
	address IPHERE
	netmask SUBNETHERE
	gateway GWHERE
	# dns-* options are implemented by the resolvconf package, if installed
	dns-nameservers DNSHERE
EOF

sed -e "s/IPHERE/$2/g"\
    -e "s/SUBNETHERE/$3/g"\
    -e "s/GWHERE/$4/g"\
    -e "s/DNSHERE/$5/g"       -i /etc/network/interfaces

#Just really make sure puppet is stopped before bringing up network
sudo /etc/init.d/puppet stop
sudo /etc/init.d/networking restart

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && sudo apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -y

#Actually enable puppet to start on next boot
[ -e /tmp/dontenablepuppet ] || sed -i -e 's/no/yes/' /etc/default/puppet

reboot
