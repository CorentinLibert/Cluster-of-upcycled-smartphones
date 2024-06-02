#!/bin/bash

usage() {
    echo "USAGE $0 COUNT INTERFACE DISTRIBUTION FILENAME"
    echo "  COUNT:          The number of measurements that should be taken (at an interval of 1 second)."
    echo "  INTERFACE:      The interface to monitor."
    echo "  DISTRIBUTION:   The distribution of the device (alpine or ubuntu). Needed for data format."
    echo "  FILENAME:       The path to the result file."
    echo "  RESET:          1 if results should overwrite existing data, otherwise results are appended."
}

help() {
    echo "Write in a file the network info (ipconfig) of a given interface at a given timestamp (in seconds). Measurements are done at an interval of 1 second."
    usage
}

COUNT=$1
INTERFACE=$2
DISTRIBUTION=$3
FILENAME=$4
RESET=$5

HEADER_RESULTS="timestamp"

# Display help and usage
if [ $1 == "-h" ] || [ $1 == "--help" ]; then 
    help
    exit 0
fi

# Check number of args
if [ $# -ne 5 ]; then
    echo "[Error] Wrong number of arguments: $#."
    usage
    exit 1
fi

if [ $DISTRIBUTION != "alpine" ] && [ $DISTRIBUTION != "ubuntu" ]; then
    echo "[ERROR] Wrong distribution. Should be either \"alpine\" or \"ubuntu\""
    usage
    exit 1
fi

# Create result file and parent directory if needed
if [ ! -f $FILENAME ] || [ $RESET -eq 1 ]; then
    mkdir -p "$(dirname $FILENAME)"
    echo "timestamp,interface,rx_packets,rx_bytes,rx_errors,rx_dropped,rx_overruns,rx_frame,tx_packets,tx_bytes,tx_errors,tx_dropped,tx_overruns,tx_carrier" > $FILENAME
fi

# Measure
for i in $(seq 1 $COUNT); do
    timestamp=$(date +%s)
    if [ $DISTRIBUTION == "alpine" ]; then
        raw_disk_info="$(ifconfig $INTERFACE | grep -E "RX|TX" | tr ':' ' ')" # Will output everything on the same line
        disk_info="$(echo $raw_disk_info | awk '{print $3,$25,$5,$7,$9,$11,$14,$30,$16,$18,$20,$22}' | tr ' ' ',')"
    elif [ $DISTRIBUTION == "ubuntu" ]; then
        raw_disk_info="$(ifconfig $INTERFACE | grep -E "RX|TX")" # Will output everything on the same line
        disk_info="$(echo $raw_disk_info | awk '{print $3,$5,$10,$12,$14,$16,$19,$21,$26,$28,$30,$32}' | tr ' ' ',')"
    fi
    echo $timestamp","$INTERFACE","$disk_info >> $FILENAME
    sleep 1
done

