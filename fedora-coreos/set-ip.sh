#!/bin/bash
nmcli con show

read -p "Enter name of NIC you'd like to set (Wired connection 1): " nic
read -p "Enter IPv4 address (192.168.1.123/24): " ipv4
read -p "Enter gateway (192.168.1.254): " gateway
read -p "Enter DNS (1.1.1.1,8.8.8.8): " dns

sudo nmcli con mod "$nic" ipv4.method manual
sudo nmcli con mod "$nic" ipv4.addresses $ipv4
sudo nmcli con mod "$nic" ipv4.gateway $gateway
sudo nmcli con mod "$nic" ipv4.dns "$dns"

sudo nmcli con up "$nic"