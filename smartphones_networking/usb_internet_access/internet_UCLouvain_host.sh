#!/bin/bash

# Restart ssh and sshd service for UCLouvain network
# You need to allow TCPForwarding and maybe GatewayPorts and/or PermitTunnel in the file /etc/ssh/sshd_config beforehand
systemctl restart ssh
systemctl restart sshd
