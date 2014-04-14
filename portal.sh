#!/bin/bash
#
# PORTALofRaspbian
# Licensed GPLv3
#
# Essentially just took the PORTAL for Debian from www.rednerd.com
# and switched some shit around to make it work for Raspbian, as my
# Alfa model is being totally rude to Arch on Pi, unfortunately.
#
# After the script runs, do whatever you gotta do and reboot. Jah bless.
#
# 99.99% credits to grugq and rednerd
#

echo "[+] PORTALofRaspbian Setup Script"

if [ "$(id -u)" != "0" ]; then
   echo "[!] Run as root." 1>&2
   exit 1
fi

echo "[+] Installing necessary goods"
apt-get install zsh vim htop lsof # good call on these, grugq. strace included in raspbian. I prefer http://ohmyz.sh/ ;)
apt-get install tor dnsmasq

echo "[+] Creating backup of /etc/network/interfaces -> interfaces-bak"
cp /etc/network/interfaces /etc/network/interfaces-bak

MACMSG="[+] Would you like to spoof wlan0's MAC address? (Y/n): "
read -n1 -p "$MACMSG" allow_spoof
echo -e "\n"

case $allow_spoof in
  [nN] ) echo "[+] Defaulting to wlan0's real MAC."
         macaddress=$(ip link show wlan0 | awk '/ether/ {print $2}')
         ;;
  *) macaddress=$(echo -n 00:18:4D; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 ":%02X"')
     echo "[+] Generated random Netgear MAC address for wlan0: $macaddress"
     ;;
esac

echo "[+] Setting up network interfaces"
cat > /etc/network/interfaces << __INTERFACES__
auto lo

iface lo inet loopback

pre-up ifconfig wlan0 hw ether $macaddress
allow-hotplug wlan0
iface wlan0 inet manual # set to manual by default, change to auto if you already have AP's setup.
wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface default inet dhcp

auto eth0
iface eth0 inet static
  # Comment out the line below, once you have the network working and tor configs
  # pre-up iptables-restore < /etc/network/iptables.tor.rules
  address 172.16.0.1
  network 172.16.0.0
  netmask 255.255.255.0
__INTERFACES__

echo "[+] Backing up /etc/tor/torrc -> torrc.bak"
cp /etc/tor/torrc /etc/tor/torrc.bak

HIDDENSERVICE="[+] Would you like to run your sshd as a hidden service? [Recommended] (Y/n): "
read -n1 -p "$HIDDENSERVICE" ssh_hs
echo -e "\n"

case $ssh_hs in
  [nN] ) echo "[+] Weaksauce."
         PISSH=""
         ;;
  *) echo "[+] Adding sshd as a hidden service for your Raspberry Pi"
     PISSH="HiddenServiceDir /var/lib/tor/hidden_service/
     HiddenServicePort 22 127.0.0.1:22
     "

     while read line;
     do
       if [[ $line == "#ListenAddress 0.0.0.0" ]]; then
         sed -i "s/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/" /etc/ssh/sshd_config
       fi
     done < /etc/ssh/sshd_config;
     ;;
esac

echo "[+] Setting up torrc..."
cat > /etc/tor/torrc << __TORRC__
AllowUnverifiedNodes middle,rendezvous
Log notice syslog
DataDirectory /var/lib/tor
$PISSH
SocksPort 9050
SocksBindAddress 127.0.0.1
SocksBindAddress 172.16.0.1:9050
VirtualAddrNetwork 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040
TransListenAddress 172.16.0.1
DNSPort 9053
DNSListenAddress 172.16.0.1
__TORRC__

echo "[+] Backing up /etc/dnsmasq.conf -> dnsmasq.conf.bak"
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
cat > /etc/dnsmasq.conf << __DNSMASQ__
bogus-priv
filterwin2k
interface=eth0
bind-interfaces
dhcp-range=172.16.0.50,172.16.0.150,12h
__DNSMASQ__

echo "[+] Setting up iptables..."
cat > /etc/network/iptables.tor.rules << __IPTABLES__
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -i eth0 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports 9040
-A PREROUTING -i eth0 -p udp -m udp --dport 53 -j REDIRECT --to-ports 9053
COMMIT
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -p icmp -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -i eth0 -p tcp -m tcp --dport 9050 -j ACCEPT
-A INPUT -i eth0 -p tcp -m tcp --dport 9040 -j ACCEPT
-A INPUT -i eth0 -p udp -m udp --dport 9053 -j ACCEPT
-A INPUT -i eth0 -p udp -m udp --dport 67 -j ACCEPT
# The rule below allows SSH access on the external interface, delete this if you don't want that.
-A INPUT -i wlan0 -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -j REJECT --reject-with tcp-reset
-A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
-A INPUT -j REJECT --reject-with icmp-proto-unreachable
COMMIT
__IPTABLES__

while read line;
do
  if [[ $line == *iptables-restore* ]]; then
    sed -i "s/# //" /etc/network/interfaces
  fi
done < /etc/network/interfaces;

service tor restart
sleep 1
service ssh reload
sleep 1

echo "[+] Setup complete"
if [ $PISSH != "" ] then;
  echo "[+] Your Pi's SSH onion: $(cat /var/lib/tor/hidden_service/hostname)"
fi
echo "[+] Reboot, plug into eth0 and giddyup"

# make sure all is gravy. If tor throws errors, either you or I did something wrong.
# if not, reboot and enjoy.
