#!/bin/bash

help() {
    echo "[USAGE] $0 DEV_TYPE_SEND_RECV N_DEVICES SSH_SENDER IP_RECEIVER N_ITER RESET FILENAME"
    echo 
    echo "ARGUMENTS"
    echo "  DEV_TYPE_SEND_RECV:     The type of the sender and receiver device (e.g. compter_smartphone)."
    echo "  N_DEVICES:              Number of devices connected to the networking medium."
    echo "  SSH_SENDER:             SSH informations of the sender (e.g. localhost, config name or with the format user@ip)."
    echo "  IP_RECEIVER:            IP address of the receiver."
    echo "  N_ITER:                 Number of time the experiment should be done."
    echo "  RESET:                  1 if should reset the bandwidth result file, append results otherwise."
    echo "  FILENAME:               The name of the results file"
}

# Parameters values
NAME=$1
N_DEVICES=$2
SSH_SENDER=$3
IP_RECEIVER=$4
N_ITER=$5
RESET=$6
FILENAME=$7

# Some Variables
N_PING=50
PING_INTERVAL=0.2
# Local
WORKDIR="$(dirname $0)"
RESULTS_DIR="$WORKDIR/results"
LATENCY_RESULTS="$RESULTS_DIR/$FILENAME"
# Remote
REMOTE_WORKDIR="~/remote_workspace_$((RANDOM))$((RANDOM))"
REMOTE_LATENCY_RESULTS="remote_latency_results.txt"

# Commands
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# SSH commands
# Remote Workspace
SETUP_REMOTE_WORKSPACE="mkdir -p $REMOTE_WORKDIR"
CLEAN_REMOTE_WORKSPACE="rm -r $REMOTE_WORKDIR"
# Bandwidth measurements
CREATE_REMOTE_LATENCY_RESULT="touch $REMOTE_WORKDIR/$REMOTE_LATENCY_RESULTS"
PERFORM_LATENCY_MEASUREMENT="ping -c $N_PING $IP_RECEIVER -i $PING_INTERVAL | sed -n '2,$(($N_PING + 1))p' >> $REMOTE_WORKDIR/$REMOTE_LATENCY_RESULTS"

# Convert time
check_seconds() {
    [[ $1 =~ ^[0-9]+(\.[0-9]+)?s$ ]]
}

check_milliseconds() {
    [[ $1 =~ ^[0-9]+(\.[0-9]+)?ms$ ]]
}

check_microseconds() {
    [[ $1 =~ ^[0-9]+(\.[0-9]+)?µs$ ]]
}

check_nanoseconds() {
    [[ $1 =~ ^[0-9]+(\.[0-9]+)?ns$ ]]
}

convert_to_milliseconds() {
    duration=$1
    if check_milliseconds "$duration"; then
        echo $(echo "$duration" | sed 's/ms//')
    elif check_microseconds "$duration"; then
        microseconds=$(echo "$duration" | sed 's/µs//') 
        echo $(bc <<< "scale=3; $microseconds / 1000")
    elif check_nanoseconds "$duration"; then
        nanoseconds=$(echo "$duration" | sed 's/ns//') 
        echo $(bc <<< "scale=6; $nanoseconds / 1000000")  
    elif check_seconds "$duration"; then
        seconds=$(echo "$duration" | sed 's/s//') 
        echo $(bc <<< "$seconds * 1000")  
    else
        echo "[ERROR] Wrong time unit: $duration"
        exit 1
    fi
}

# Experiment functions 
setup_local_workspace() {
    if [[ "$RESET" -eq 1 ]]; then
        echo "[INFO] Remove previous result files."
        rm -r $LATENCY_RESULTS
    fi
    if ! test -f "$LATENCY_RESULTS"; then
        echo "[INFO] Create results files and parent directory."
        mkdir -p $RESULTS_DIR
        echo "dev_types_send_recv,n_devices,latency_ms" > $LATENCY_RESULTS
    fi
}

setup_remote_workspace() {
    echo "[INFO] Create remote workspace on sender."
    $SSH_COMMAND $SSH_SENDER $SETUP_REMOTE_WORKSPACE
}

clean_remote_workspace() {
    echo "[INFO] Clean remote workspace on sender."
	$SSH_COMMAND $SSH_SENDER $CLEAN_REMOTE_WORKSPACE
}

measure_latency() {
    echo "[INFO] Create remote latency results file on sender."
    $SSH_COMMAND $SSH_SENDER $CREATE_REMOTE_LATENCY_RESULT

    echo "[INFO] Start measurements."
    for I in $(seq 1 $N_ITER); do
        echo "  $I/$N_ITER iterations."
        $SSH_COMMAND $SSH_SENDER $PERFORM_LATENCY_MEASUREMENT
        sleep 2
    done

    echo "[INFO] Retrieve remote data."
    $SCP_COMMAND $SSH_SENDER:$REMOTE_WORKDIR/$REMOTE_LATENCY_RESULTS $RESULTS_DIR

    echo "[INFO] Format data into results file."
    while IFS= read -r line; do
		latency=$(echo "$line" | awk '{print $7 $8}' | sed 's/time=//g')
        latency_in_ms=$(convert_to_milliseconds $latency)
		echo "$NAME,$N_DEVICES,$latency_in_ms" >> $LATENCY_RESULTS
	done < $RESULTS_DIR/$REMOTE_LATENCY_RESULTS
	rm $RESULTS_DIR/$REMOTE_LATENCY_RESULTS
}

setup_local_workspace
setup_remote_workspace
measure_latency
clean_remote_workspace
