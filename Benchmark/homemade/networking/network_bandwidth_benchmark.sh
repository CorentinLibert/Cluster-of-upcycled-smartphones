#!/bin/bash

help() {
    echo "[USAGE] $0 DEV_TYPE_SEND_RECV N_DEVICES SSH_SENDER SSH_RECEIVER IP_RECEIVER N_ITER RESET FILENAME"
    echo 
    echo "ARGUMENTS"
    echo "  DEV_TYPE_SEND_RECV:     The type of the sender and receiver device (e.g. compter_smartphone)."
    echo "  N_DEVICES:              Number of devices connected to the networking medium."
    echo "  SSH_SENDER:             SSH informations of the sender (e.g. localhost, config name or with the format user@ip)."
    echo "  SSH_RECEIVER:           SSH informations of the receiver (e.g. localhost, config name or with the format user@ip)."
    echo "  IP_RECEIVER:            IP address of the receiver."
    echo "  N_ITER:                 Number of time the experiment should be done."
    echo "  RESET:                  1 if should reset the bandwidth result file, append results otherwise."
    echo "  FILENAME:               The name of the results file"
}

# Parameters values
NAME=$1
N_DEVICES=$2
SSH_SENDER=$3
SSH_RECEIVER=$4
IP_RECEIVER=$5
N_ITER=$6
RESET=$7
FILENAME=$8

# Some Variables
# Local
WORKDIR="$(dirname $0)"
RESULTS_DIR="$WORKDIR/results"
BANDWIDTH_RESULTS="$RESULTS_DIR/$FILENAME"
# Remote
REMOTE_WORKDIR="~/remote_workspace_$((RANDOM))$((RANDOM))"
REMOTE_BANDWIDTH_RESULTS="remote_bandwidth_results.txt"

# Commands
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# SSH commands
# Remote Workspace
SETUP_REMOTE_WORKSPACE="mkdir -p $REMOTE_WORKDIR"
CLEAN_REMOTE_WORKSPACE="rm -r $REMOTE_WORKDIR"
# Bandwidth measurements
CREATE_REMOTE_BANDWIDTH_RESULT="touch $REMOTE_WORKDIR/$REMOTE_BANDWIDTH_RESULTS"
START_IPERF3_SERVER="iperf3 -s -D"
PERFORM_BANDWIDTH_MEASUREMENT="iperf3 -c $IP_RECEIVER -f m --time 22 --omit 2 | grep receiver >> $REMOTE_WORKDIR/$REMOTE_BANDWIDTH_RESULTS"
STOP_IPERF3_SERVER='kill $(pidof iperf3)'

setup_local_workspace() {
    if [ $RESET -eq 1 ]; then
        echo "[INFO] Remove previous result files."
        rm -r $BANDWIDTH_RESULTS
    fi 
    if ! test -f "$BANDWIDTH_RESULTS"; then
        echo "[INFO] Create results files and parent directory."
        mkdir -p $RESULTS_DIR
        echo "dev_types_send_recv,n_devices,bandwidth_mbits_sec" > $BANDWIDTH_RESULTS
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

measure_bandwidth() {
    echo "[INFO] Create remote bandwidth results file on sender."
    $SSH_COMMAND $SSH_SENDER $CREATE_REMOTE_BANDWIDTH_RESULT

    echo "[INFO] Start iperf3 daemon server on receiver."
    $SSH_COMMAND $SSH_RECEIVER $START_IPERF3_SERVER
    sleep 1

    echo "[INFO] Start measurements."
    for I in $(seq 1 $N_ITER); do
        echo "  $I/$N_ITER iterations."
        $SSH_COMMAND $SSH_SENDER $PERFORM_BANDWIDTH_MEASUREMENT
        sleep 2
    done

    echo "[INFO] Stop iperf3 server."
    $SSH_COMMAND $SSH_RECEIVER $STOP_IPERF3_SERVER

    echo "[INFO] Retrieve remote data."
    $SCP_COMMAND $SSH_SENDER:$REMOTE_WORKDIR/$REMOTE_BANDWIDTH_RESULTS $RESULTS_DIR

    echo "[INFO] Format data into results file."
    while IFS= read -r line; do
		bandwidth=$(echo "$line" | awk '{print $7}')
		echo "$NAME,$N_DEVICES,$bandwidth" >> $BANDWIDTH_RESULTS
	done < $RESULTS_DIR/$REMOTE_BANDWIDTH_RESULTS
	rm $RESULTS_DIR/$REMOTE_BANDWIDTH_RESULTS
}



setup_local_workspace
setup_remote_workspace
measure_bandwidth
clean_remote_workspace
