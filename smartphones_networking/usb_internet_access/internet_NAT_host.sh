#!/bin/bash

# Based on: https://wiki.postmarketos.org/wiki/USB_Internet
sysctl net.ipv4.ip_forward=1
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s 172.16.42.0/24 -j ACCEPT
iptables -A POSTROUTING -t nat -j MASQUERADE -s 172.16.42.0/24
iptables-save

