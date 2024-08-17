#!/bin/bash

usage() {
    echo "USAGE $0 COUNT FILENAME"
    echo "  COUNT:          The number of measurements that should be taken (at an interval of 1 second)."
    echo "  FILENAME:       The path to the result file."
    echo "  INTERFACE:      The interface to monitor."
    echo "  RESET:          1 if results should overwrite existing data, otherwise results are appended."
}

help() {
    echo "Write in a file the network info (ipconfig) of a given interface at a given timestamp (in seconds). Measurements are done at an interval of 1 second."
    usage
}

COUNT=$1
FILENAME=$2
INTERFACE=$3
RESET=$4

# Display help and usage
if [ $1 == "-h" ] || [ $1 == "--help" ]; then 
    help
    exit 0
fi

# Check number of args
if [ $# -ne 4 ]; then
    echo "[Error] Wrong number of arguments: $#."
    usage
    exit 1
fi

# Create result file and parent directory if needed
if [ ! -f $FILENAME ] || [ $RESET -eq 1 ]; then
    mkdir -p "$(dirname $FILENAME)"
    echo "rx_bytes,tx_bytes" > $FILENAME
fi

# Measure
for i in $(seq 1 $COUNT); do
    timestamp=$(date +%s)
    net_info="$(ifconfig $INTERFACE | grep -E "RX bytes|TX bytes" | awk '{print $2, $6}' |  sed 's/bytes://g' | sed 's/ /,/g')"
    echo $timestamp","$net_info >> $FILENAME
    sleep 1
done















