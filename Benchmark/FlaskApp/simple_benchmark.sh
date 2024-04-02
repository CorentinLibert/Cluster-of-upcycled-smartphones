#!/bin/bash

# Function definition
Help()
{
    echo "This script is a simple benchmark designed to measure the performances of a K3S cluster."
    echo "The selected usecase is the image classification inference on images representing a video stream."
    echo
    echo "The new assigned IPv4 addresses are assigned incrementaly from 172.16.42.3 to 172.16.42.254 included. The 4 remaining addresses are reserved as follows for future purpose:"
    echo "  172.16.42.1:    Default IPv4 address of the devices."
    echo "  172.16.42.2:    Default IPv4 address of the host."
    echo "  172.16.42.254:  IPv4 address for gateway (not used yet, currently 172.16.42.2 is used)"
    echo "  172.16.42.255:  IPv4 address used for broadcasting (not used)"
    echo "This script has to be run with root privileges."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo "  -n              The total number of request that has to be done."
    echo "  -r              The rate at which request has to be done. It corresponds to the number of frames per second."
    echo "  -R              The number of replicas of the application on the cluster."
    echo "  -p <password>   Specify a different password for the SSH connection (default: \"dummy\")."
    echo "  -u <username>   Specify a different username for the SSH connection (default: \"pptc\")".
    echo "  -h              Show this help message."
}

# Number of requests
N=10
# Rate of requests per second
R=8

# Function to send request and measure time
send_request() {
    local id=$1
    local start_time=$(($(date +%s%N)/1000000))
    local response=$(curl -s -X POST -F "image=@grace_hopper.bmp" http://192.168.88.4:31000)
    local end_time=$(($(date +%s%N)/1000000))
    local duration=$(($end_time - $start_time)) # Convert nanoseconds to milliseconds
    echo "$id, $start_time, $end_time, $duration, $response" >> response_times.txt
}

sleep_duration=$(echo "scale=4; 1 / $R" | bc)
echo "Rate of $R request/second (time between request: $sleep_duration second)"

# Main loop to send requests
echo "id, start_time, end_time, duration, response" > response_times.txt
for ((i=1; i<=N; i++)); do
    send_request $i & # Execute function in background to create new thread
    echo "Start sleeping"
    sleep $sleep_duration
    echo "Stop sleeping"
done

# Wait for all background processes to finish
wait
echo "All requests completed."
