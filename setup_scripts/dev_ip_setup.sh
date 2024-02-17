#!/bin/bash

Help()
{
    echo "This script allows to reconfigure the IPv4 of a device connected to the host and the routes to it." 
    echo "This script has to be run with root privileges."
    echo
    echo "Usage: $0 INTERFACE IPV4 [OPTIONS]"
    echo 
    echo "INTERFACE:        The networking interface of the connected device on the host."
    echo "IPV4:             The new IPv4 address assigned to the connected device."
    echo "OPTIONS:"
    echo "  -d              Stop the dhcpd server to avoid dhcp route creation on host (default: keep the dhcpd server running)."
    echo "  -p <password>   Specify a different password for the SSH connection (default: \"dummy\")."
    echo "  -u <username>   Specify a different username for the SSH connection (default: \"pptc\")".
    echo "  -h              Show this help message."
}

# Default values
DEFAULT_HOST_IPV4="172.16.42.2"
DEFAULT_DEVICE_IPV4="172.16.42.1"
SSH_USERNAME="pptc"
SSH_PASSWORD="dummy"
STOP_DHCPD=0    # 1 if DHCPD service must be stopped, default 0

# Define utility functions
is_valid_ipv4() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS="."
        for octet in $ip; do
            if (( $octet < 0 || $octet > 255)); then
                return 1;
            fi
        done
        return 0;
    fi
    return 1; 
}

is_existing_interface() {
    local interface="$1"
    local existing_interfaces=$(ip link show | awk '{print $2}' | sed -n 'p;n' | sed -n '/^enx/s/.$//p')
    for i in $existing_interfaces; do
        if [ $interface = $i ]; then 
            return 0;
        fi
    done
    return 1;
}

# Check number of mandatory arguments
if [ $# -lt 2 ]; then
    echo "Error: Insuffisent arguments."
    Help
    exit 1
fi

# Get mandatory arguments
interface="$1"
new_ipv4="$2"

shift 2

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

echo "Check arguments..."
# Check arguments validity
if ! is_existing_interface $interface; then
    echo "Error: Wrong interface: \"$interface\" is not an existing EtherNet eXternal interface."
    exit 1 
elif ! is_valid_ipv4 $new_ipv4; then
    echo "Error: Wrong new IPv4: \"$new_ipv4\" is not of the form X.X.X.X (with X being a value between 0 and 255)."
    exit 1
fi

# For SSH connection in case of multiple interfaces with same IP:
# Ensure priority of the given interface by giving a longer subnet.
echo "Add new route..."
ip route add "$DEFAULT_DEVICE_IPV4"/32 dev "$interface" src "$DEFAULT_HOST_IPV4" >> /dev/null 2>&1

# Add new ipv4 address
echo "SSH Connection on ${DEFAULT_DEVICE_IPV4} for interface ${interface}"
sshpass -p "$SSH_PASSWORD" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T "$SSH_USERNAME"@"$DEFAULT_DEVICE_IPV4" << EOF
    echo "$SSH_PASSWORD" | sudo -S ip address add "$new_ipv4" dev usb0
    sudo ip route add 172.16.42.0/24 via "${DEFAULT_HOST_IPV4}" dev usb0 src "$new_ipv4"
EOF

# Stop dhcpd server in order to remove old route
if [ $STOP_DHCPD -eq 1 ]; then
    echo "Stopping dhcpd service"
    service dhcpd stop
fi

# Change route for the given interface on host
ip route add "$new_ipv4"/32 dev "$interface" src "$DEFAULT_HOST_IPV4" >> /dev/null 2>&1
ip route del "$DEFAULT_DEVICE_IPV4"/32 dev "$interface" src "$DEFAULT_HOST_IPV4" >> /dev/null 2>&1
ip route del 172.16.42.0/24 dev "$interface"

# Removed because crashed sometimes due to the SSH connection (no cleanup of old route/ip done)
# Currently, priority in networking is done through longest address/subnet
# # SSH connection through new IPv4, avoiding crash of the SSH connection when removing old IPv4 address
# echo "SSH Connection on ${new_ipv4} for interface ${interface}"
# sshpass -p "$SSH_PASSWORD" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -T "$SSH_USERNAME"@"$new_ipv4" << EOF
#     echo "$SSH_PASSWORD" | sudo -S ip address del "$DEFAULT_DEVICE_IPV4"/16 dev usb0
# EOF

exit 0
