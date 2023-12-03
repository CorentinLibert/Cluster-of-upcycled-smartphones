#!/bin/bash

# Script based on https://wiki.postmarketos.org/wiki/USB_Internet
# Temporarily creates a NAT on the host (computer) in order to forward internet request from the device (smartphone).
sysctl net.ipv4.ip_forward=1
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s 172.16.42.0/24 -j ACCEPT
iptables -A POSTROUTING -t nat -j MASQUERADE -s 172.16.42.0/24
iptables-save #Save changes
