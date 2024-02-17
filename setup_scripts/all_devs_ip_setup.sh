#!/bin/bash

Help()
{
    echo "This script allows to reconfigure the IPv4 and the routes of all EtherNet eXternal (USB) devices, having network interface starting with the prefix \"enx\", connected to the host."
    echo "Initially, no configuration must have occurred on the connected device. All devices should have 172.16.42.1 as default IPv4 address."
    echo
    echo "The new assigned IPv4 addresses are assigned incrementaly from 172.16.42.3 to 172.16.42.254 included. The 4 remaining addresses are reserved as follows for future purpose:"
    echo "  172.16.42.1:    Default IPv4 address of the devices."
    echo "  172.16.42.2:    Default IPv4 address of the host."
    echo "  172.16.42.254:  IPv4 address for gateway (not used yet, currently 172.16.42.2 is used)"
    echo "  172.16.42.255:  IPv4 address used for broadcasting (not used)"
    echo "This script has to be run with root privileges."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo "  -d              Stop the dhcpd server to avoid dhcp route creation on host (default: keep the dhcpd server running)."
    echo "  -p <password>   Specify a different password for the SSH connection (default: \"dummy\")."
    echo "  -u <username>   Specify a different username for the SSH connection (default: \"pptc\")".
    echo "  -h              Show this help message."
}

# Default values
SSH_USERNAME="pptc"
SSH_PASSWORD="dummy"
STOP_DHCPD=0    # 1 if DHCPD service must be stopped, default 0

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this script with sudo or as root."
    exit 1
fi

# Check optional arguments
while getopts ":dp:u:h" option; do
    case ${option} in
        d)STOP_DHCPD=1;;
        p)SSH_PASSWORD=${OPTARG};;
        u)SSH_USERNAME=${OPTARG};;
        h)Help
          exit;;
        \?) echo "Error: Invalid option: ${option}"
            Help
            exit 1;;
    esac
done

# Retrieve all networking interface starting with prefix "enx"
existing_interfaces=$(ip link show | awk '{print $2}' | sed -n 'p;n' | sed -n '/^enx/s/.$//p')
i=3

if [ ${#existing_interfaces[@]} -eq 0 ]; then
    echo "No device found."
    exit 0
fi

if [ $STOP_DHCPD -eq 1 ]; then
    echo "Stopping dhcpd service"
    service dhcpd stop
fi

echo "Allowing IPv4 forwarding on host..."
sysctl -w net.ipv4.ip_forward=1

for interface in ${existing_interfaces}
do
    echo "${interface}"
    if [ $i -gt 253 ]; then
        echo "Error: No more IPv4 addresses available for this subnet."
        exit 1
    fi
    echo "Configure first smartphone..."
    ./dev_ip_setup.sh ${interface} 172.16.42.${i} -p ${SSH_PASSWORD} -u ${SSH_USERNAME}
    i=$(( $i + 1 ))
done

exit 0
