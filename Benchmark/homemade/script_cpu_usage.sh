#!/bin/bash

# Configuration
PATH_RESULT_FILE="/home/corentin/Documents/TFE/TFE_Git/Benchmark/homemade/results.txt"
DURATION=10

help(){
    echo "Print CPU usage into the result file. CPU usage is retrieved each second for a given duration."
    echo "  Usage: $0 PATH_RESULT_FILE DURATION"
}

script() {
    # Get cpu stat every second
    for I in $(seq 1 $DURATION); do
        # In seconds, %N does not work on a BusyBox system: see https://stackoverflow.com/a/38872276
        date +%s >> $PATH_RESULT_FILE 
        cat /proc/stat | head -n 1 >> $PATH_RESULT_FILE
        sleep 1
    done
}

# Arguments handler and configuration
if [ $# -ne 2 ]; then
    echo "Error: Wrong number of arguments: $#."
    help
    exit 1
fi

PATH_RESULT_FILE=$1
DURATION=$2

# Script
script