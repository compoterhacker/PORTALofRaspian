#!/bin/bash
#
# PORTALofRaspian
# Licensed GPLv3
#
# Essentially just took the PORTAL for Debian from www.rednerd.com
# and switched some shit around to make it work for Raspian, as my
# Alfa model is being totally rude to Arch on Pi, unfortunately.
#
# After the sript runs, do whatever you gotta do and reboot. Jah bless.
#
# 99.99% credits to grugq and rednerd
#

apt-get install zsh vim htop lsof # good call on these, grugq. strace included in raspian. I prefer http://ohmyz.sh/ ;)
apt-get install tor dnsmasq

cp /etc/network/interfaces /etc/network/interfaces-bak

cat > /etc/network/interfaces << __INTERFACES__
auto lo

iface lo inet loopback

pre-up ifconfig wlan0 hw ether 00:00:00:00:00:00 # change wlan0's mac address
allow-hotplug wlan0
iface wlan0 inet manual
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

cp /etc/tor/torrc /etc/tor/torrc.bak
cat > /etc/tor/torrc << __TORRC__
AllowUnverifiedNodes middle,rendezvous
Log notice syslog
DataDirectory /var/lib/tor
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

cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
cat > /etc/dnsmasq.conf << __DNSMASQ__
bogus-priv
filterwin2k
interface=eth0
bind-interfaces
dhcp-range=172.16.0.50,172.16.0.150,12h
__DNSMASQ__

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

/etc/init.d/tor start

# make sure all is gravy. If tor throws errors, either you or I did something wrong.
# if not, reboot and enjoy.
