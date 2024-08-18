#!/bin/bash

usage() {
    echo "USAGE $0 COUNT FILENAME"
    echo "  COUNT:          The number of measurements that should be taken (at an interval of 1 second)."
    echo "  FILENAME:       The path to the result file."
    echo "  RESET:          1 if results should overwrite existing data, otherwise results are appended."
}

help() {
    echo "Write in a file the cpu info (/proc/stat), in seconds, at given timestamps (in seconds). Measurements are done at an interval of 1 second."
    usage
}

COUNT=$1
FILENAME=$2
RESET=$3

# Display help and usage
if [ $1 == "-h" ] || [ $1 == "--help" ]; then 
    help
    exit 0
fi

# Check number of args
if [ $# -ne 3 ]; then
    echo "[Error] Wrong number of arguments: $#."
    usage
    exit 1
fi

# Create result file and parent directory if needed
if [ ! -f $FILENAME ] || [ $RESET -eq 1 ]; then
    mkdir -p "$(dirname $FILENAME)"
    echo "timestamp,user,nice,system,idle,iowait,irq,softirq" > $FILENAME
fi

# Measure
for i in $(seq 1 $COUNT); do
    timestamp=$(date +%s)
    cpu_info="$(cat /proc/stat | grep -w 'cpu' | cut -d ' ' -f2-9 | sed 's/^ //' | tr ' ' ',')"
    echo $timestamp","$cpu_info >> $FILENAME
    sleep 1
done

