#!/bin/bash

usage() {
    echo "USAGE $0 COUNT FILESYSTEM FILENAME"
    echo "  COUNT:          The number of measurements that should be taken (at an interval of 1 second)."
    echo "  FILESYSTEM:     The filesystem to monitor."
    echo "  FILENAME:       The path to the result file."
}

help() {
    echo "Write in a file the disk info (df command) for a given filesystem, in kilobytes (kB) (1024 bytes), at given timestamps (in seconds). Measurements are done at an interval of 1 second."
    usage
}

COUNT=$1
FILESYSTEM=$2
FILENAME=$3

HEADER_RESULTS="timestamp"

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
mkdir -p "$(dirname $FILENAME)"
echo "timestamp,filesystem,n_blocks,used,available" > $FILENAME

# Measure
for i in $(seq 1 $COUNT); do
    timestamp=$(date +%s)
    disk_info="$(df -k $FILESYSTEM | tail -n -1 | sed "s|$FILESYSTEM *||" | awk '{print $1","$2","$3}')"
    echo $timestamp","$FILESYSTEM","$disk_info >> $FILENAME
    sleep 1
done

