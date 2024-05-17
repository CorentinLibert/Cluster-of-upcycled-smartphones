#!/bin/bash

help() {
    echo "[USAGE] $0 N_DEVICES SSH_SENDERS SSH_RECEIVERS IP_RECEIVERS N_ITER RESET FILENAME"
    echo 
    echo "ARGUMENTS"
    echo "  N_DEVICES:              Number of devices connected to the networking medium."
    echo "  SSH_SENDERS:            List of SSH informations of the senders (e.g. \"localhost pptc@192.168.88.252\")."
    echo "  SSH_RECEIVERS:          List of SSH informations of the receivers (e.g. \"localhost pptc@192.168.88.252\")."
    echo "  IP_RECEIVERS:           List of the IP address of the receivers (e.g. \"192.168.88.252 192.168.88.251\")."
    echo "  N_ITER:                 Number of time the experiment should be done."
    echo "  RESET:                  1 if should reset the bandwidth result file, append results otherwise."
    echo "  FILENAME:               The name of the results file"
}

# Parameters values
N_DEVICES=$1
read -a SSH_SENDERS <<< "$2"
read -a SSH_RECEIVERS <<< "$3"
read -a IP_RECEIVERS <<< "$4"
N_ITER=$5
RESET=$6
FILENAME=$7

# Some Variables
MEASURE_DURATION=22
OMIT_DURATION=2
# Local
WORKDIR="$(dirname $0)"
RESULTS_DIR="$WORKDIR/results"
BANDWIDTH_RESULTS="$RESULTS_DIR/$FILENAME"
# Remote
REMOTE_WORKDIR="~/remote_workspace_$((RANDOM))$((RANDOM))"
REMOTE_BANDWIDTH_RESULTS="remote_bandwidth_results" # Without file extension (added after adding sender info)

# Commands
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# SSH commands
# Remote Workspace
SETUP_REMOTE_WORKSPACE="mkdir -p $REMOTE_WORKDIR"
CLEAN_REMOTE_WORKSPACE="rm -r $REMOTE_WORKDIR"
# Bandwidth measurements
START_IPERF3_SERVER="iperf3 -s -D"
PERFORM_BANDWIDTH_MEASUREMENT="iperf3 -c $IP_RECEIVER -f m --time $MEASURE_DURATION --omit $OMIT_DURATION | grep receiver >> $REMOTE_WORKDIR/$REMOTE_BANDWIDTH_RESULTS"
STOP_IPERF3_SERVER='kill $(pidof iperf3)'

setup_local_workspace() {
    if [ $RESET -eq 1 ]; then
        echo "[INFO] Remove previous result files."
        rm -r $BANDWIDTH_RESULTS
    fi 
    if ! test -f "$BANDWIDTH_RESULTS"; then
        echo "[INFO] Create results files and parent directory."
        mkdir -p $RESULTS_DIR
        echo "n_devices,n_connections,bandwidth_mbits_sec" > $BANDWIDTH_RESULTS
    fi
}

setup_remote_workspace() {
    for i in "${!SSH_SENDERS[@]}";
    do
        sender=${SSH_SENDERS[$i]}
        echo "[INFO] Create remote workspace on sender $sender."
        $SSH_COMMAND $sender $SETUP_REMOTE_WORKSPACE
        echo "[INFO] Create remote bandwidth results file on sender $sender."
        CREATE_REMOTE_BANDWIDTH_RESULT="touch $REMOTE_WORKDIR/$REMOTE_BANDWIDTH_RESULTS$sender.txt"
        $SSH_COMMAND $sender $CREATE_REMOTE_BANDWIDTH_RESULT
    done
}

clean_remote_workspace() {
    for i in "${!SSH_SENDERS[@]}";
    do
        sender=${SSH_SENDERS[$i]}
        echo "[INFO] Clean remote workspace on sender $sender."
        $SSH_COMMAND $sender $CLEAN_REMOTE_WORKSPACE
    done
}

measure_bandwidth() {
    for i in "${!SSH_RECEIVERS[@]}";
    do
        receiver=${SSH_RECEIVERS[$i]}
        echo "[INFO] Start iperf3 daemon server on receiver $receiver."
        $SSH_COMMAND $receiver $START_IPERF3_SERVER
    done
    sleep 5

    
    echo "[INFO] Start measurements."
    for I in $(seq 1 $N_ITER); do
        echo "  $I/$N_ITER iterations."
        for i in "${!SSH_SENDERS[@]}";
        do
            sender=${SSH_SENDERS[$i]}
            ip_receiver=${IP_RECEIVERS[$i]}
            echo "      [INFO] Perform iperf3 on sender $sender to receiver with ip $ip_receiver."
            PERFORM_BANDWIDTH_MEASUREMENT="iperf3 -c $ip_receiver -f m --time $MEASURE_DURATION --omit $OMIT_DURATION | grep receiver >> $REMOTE_WORKDIR/$REMOTE_BANDWIDTH_RESULTS$sender.txt"
            $SSH_COMMAND $sender $PERFORM_BANDWIDTH_MEASUREMENT &
        done
        echo "      [INFO] Wait for the end of this iteration measurements."
        sleep $(($MEASURE_DURATION+10))
    done

    echo "[INFO] Stop iperf3 server."
    for i in "${!SSH_RECEIVERS[@]}";
    do
        receiver=${SSH_RECEIVERS[$i]}
        $SSH_COMMAND $receiver $STOP_IPERF3_SERVER
    done

    echo "[INFO] Retrieve remote data."
    rm -r $RESULTS_DIR/tmp_results
    mkdir -p $RESULTS_DIR/tmp_results
    for i in "${!SSH_SENDERS[@]}";
    do
        sender=${SSH_SENDERS[$i]}
        $SCP_COMMAND $sender:$REMOTE_WORKDIR/$REMOTE_BANDWIDTH_RESULTS$sender.txt $RESULTS_DIR/tmp_results
    done

    echo "[INFO] Format data into results file."
    for i in "${!SSH_SENDERS[@]}";
    do
        sender=${SSH_SENDERS[$i]}
        while IFS= read -r line; do
            bandwidth=$(echo "$line" | awk '{print $7}')
            echo "$N_DEVICES,$i,$bandwidth" >> $BANDWIDTH_RESULTS
        done < $RESULTS_DIR/tmp_results/$REMOTE_BANDWIDTH_RESULTS$sender.txt
    done
	rm -r $RESULTS_DIR/tmp_results
}

if [ ${#SSH_SENDERS[@]} -ne ${#SSH_RECEIVERS[@]} ] || [ ${#SSH_SENDERS[@]} -ne ${#IP_RECEIVERS[@]} ]; then
    echo "[ERROR] The number of SSH senders, SSH receivers and receivers IP addresses must be the same."
    exit 1
fi

#   for i in "${!SSH_RECEIVERS[@]}";
#     do
#         receiver=${SSH_RECEIVERS[$i]}
#         $SSH_COMMAND $receiver $STOP_IPERF3_SERVER
#     done

setup_local_workspace
setup_remote_workspace
measure_bandwidth
clean_remote_workspace
