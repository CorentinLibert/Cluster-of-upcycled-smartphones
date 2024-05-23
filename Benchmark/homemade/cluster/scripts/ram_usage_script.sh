#!/bin/bash

usage() {
    echo "USAGE $0 COUNT FILENAME"
    echo "  COUNT:          The number of measurements that should be taken (at an interval of 1 second)."
    echo "  FILENAME:       The path to the result file."
}

help() {
    echo "Write in a file the memory info (/proc/meminfo), in kibibytes (kB) (1024 bytes), at given timestamps (in seconds). Measurements are done at an interval of 1 second."
    usage
}

COUNT=$1
FILENAME=$2

# Display help and usage
if [ $1 == "-h" ] || [ $1 == "--help" ]; then 
    help
    exit 0
fi

# Check number of args
if [ $# -ne 2 ]; then
    echo "[Error] Wrong number of arguments: $#."
    usage
    exit 1
fi

# Create result file and parent directory if needed
mkdir -p "$(dirname $FILENAME)"
echo "timestamp,memtotal,memfree,memavailable,cache,buffer,swaptotal,swapfree,swapcached" > $FILENAME

# Measure
for i in $(seq 1 $COUNT); do
    timestamp=$(date +%s)
    mem_info="$(cat /proc/meminfo | grep -E 'Mem|Cache|Buffer|Swap' | awk '{print $2}' | paste -sd,)"
    echo $timestamp","$mem_info >> $FILENAME
    sleep 1
done

