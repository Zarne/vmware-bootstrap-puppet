#!/bin/bash
set -ex

#Redirect stdout and stderr
#We need to append to logs, to get output from both
#parent process and child process
exec >>  customization.log
exec 2>> customization.err

HOSTNAME=$1
IP=$2
SUBNET=$3
GATEWAY=$4
DNS=$5

if [ -z "$SUDO_COMMAND" ]
then
  sudo /sbin/ip a a $IP/$SUBNET dev eth0
  sudo /sbin/ip link set dev eth0 up
  sudo /sbin/ip r a default via $GATEWAY
  echo "doing git update"
  ( cd vmware-bootstrap-puppet/ && git pull )
  echo "relaunching with elevated previliges"
  sudo $0 $*
  exit 0
fi

rm -rf /etc/udev/rules.d/70-persistent-net.rules

echo $HOSTNAME > /etc/hostname
/bin/cat > /etc/network/interfaces <<EOF
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

/bin/sed -e "s/IPHERE/$2/g"\
    -e "s/SUBNETHERE/$3/g"\
    -e "s/GWHERE/$4/g"\
    -e "s/DNSHERE/$5/g"       -i /etc/network/interfaces

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -y

# Delete temp template hostname
/bin/sed '/127.0.1.1.*kimo.sw.in/d' -i /etc/hosts
# Add real hostname
echo "$IP      $HOSTNAME" >> /etc/hosts

#Actually enable puppet to start on next boot
[ -e /tmp/dontenablepuppet ] || sed -i -e 's/=no/=yes/' /etc/default/puppet

reboot &
