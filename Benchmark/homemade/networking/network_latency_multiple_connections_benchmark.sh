#!/bin/bash

help() {
    echo "[USAGE] $0 N_DEVICES SSH_SENDERS SSH_RECEIVERS IP_RECEIVERS N_ITER RESET FILENAME"
    echo 
    echo "ARGUMENTS"
    echo "  N_DEVICES:              Number of devices connected to the networking medium."
    echo "  SSH_SENDERS:            List of SSH informations of the senders (e.g. \"localhost pptc@192.168.88.252\")."
    echo "  SSH_RECEIVERS:          List of SSH informations of the receivers (e.g. \"localhost pptc@192.168.88.252\")."
    echo "  IP_RECEIVERS:           List of the IP address of the receivers (e.g. \"192.168.88.252 192.168.88.251\")."
    echo "  PING_INTERVAL           The interval between two pings."
    echo "  N_ITER:                 Number of time the experiment should be done."
    echo "  DIFF_DEVICE             A if latency measurement and workload creation are between different device, 0 else"
    echo "  RESET:                  1 if should reset the bandwidth result file, append results otherwise."
    echo "  FILENAME:               The name of the results file"
}

# Parameters values
N_DEVICES=$1
read -a SSH_SENDERS <<< "$2"
read -a SSH_RECEIVERS <<< "$3"
read -a IP_RECEIVERS <<< "$4"
PING_INTERVAL=$5
N_ITER=$6
DIFF_DEVICE=$7
RESET=$8
FILENAME=$9

# Some Variables
N_PING=30
PING_DURATION=$(echo "scale=0;(($N_PING * $PING_INTERVAL)+0.5)/1" | bc)
DELTA_DURATION=5
WORKLOAD_DURATION=$(($PING_DURATION+2*$DELTA_DURATION))
# Local
WORKDIR="$(dirname $0)"
RESULTS_DIR="$WORKDIR/results"
LATENCY_RESULTS="$RESULTS_DIR/$FILENAME"
# Remote
REMOTE_WORKDIR="~/remote_workspace_$((RANDOM))$((RANDOM))"
REMOTE_LATENCY_RESULTS="remote_latency_mult_con_results" # Without file extension (added after adding sender info)

# Commands
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# SSH commands
# Remote Workspace
SETUP_REMOTE_WORKSPACE="mkdir -p $REMOTE_WORKDIR"
CLEAN_REMOTE_WORKSPACE="rm -r $REMOTE_WORKDIR"
# Bandwidth measurements
START_IPERF3_SERVER="iperf3 -s -D"
PERFORM_BANDWIDTH_MEASUREMENT="iperf3 -c $IP_RECEIVER -f m --time $WORKLOAD_DURATION --omit $OMIT_DURATION | grep receiver >> $REMOTE_WORKDIR/$REMOTE_LATENCY_RESULTS"
STOP_IPERF3_SERVER='kill $(pidof iperf3)'

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
        echo -1
    fi
}

setup_local_workspace() {
    if [ $RESET -eq 1 ]; then
        echo "[INFO] Remove previous result files."
        rm -r $LATENCY_RESULTS
    fi 
    if ! test -f "$LATENCY_RESULTS"; then
        echo "[INFO] Create results files and parent directory."
        mkdir -p $RESULTS_DIR
        echo "n_devices,n_connections,latency_ms" > $LATENCY_RESULTS
    fi
}

setup_remote_workspace() {
    for i in "${!SSH_SENDERS[@]}";
    do
        sender=${SSH_SENDERS[$i]}
        echo "[INFO] Create remote workspace on sender $sender."
        $SSH_COMMAND $sender $SETUP_REMOTE_WORKSPACE
        echo "[INFO] Create remote results file on sender $sender."
        CREATE_REMOTE_RESULT_FILE="touch $REMOTE_WORKDIR/$REMOTE_LATENCY_RESULTS$sender.txt"
        $SSH_COMMAND $sender $CREATE_REMOTE_RESULT_FILE
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

measure_latency() {
    for i in "${!SSH_RECEIVERS[@]}";
    do
        receiver=${SSH_RECEIVERS[$i]}
        echo "[INFO] Start iperf3 daemon server on receiver $receiver."
        $SSH_COMMAND $receiver $START_IPERF3_SERVER
    done
    sleep 5

    
    echo "[INFO] Create random workload with iperf3. (Workload duration: $WORKLOAD_DURATION seconds)"
    for I in $(seq 1 $N_ITER); do
        echo "  $I/$N_ITER iterations."
        for i in "${!SSH_SENDERS[@]}";
        do
            sender=${SSH_SENDERS[$i]}
            ip_receiver=${IP_RECEIVERS[$i]}
            echo "      [INFO] Perform iperf3 on sender $sender towards receiver with ip $ip_receiver."
            CREATE_RANDOM_WORKLOAD="iperf3 -c $ip_receiver -f m --time $WORKLOAD_DURATION > /dev/null"
            $SSH_COMMAND $sender $CREATE_RANDOM_WORKLOAD &
        done

        sleep $DELTA_DURATION # Wait for iperf3 workload to start

        echo "      [INFO] Perform latency measurements ($N_PING pings with interval of $PING_INTERVAL (Total duration: $PING_DURATION))"
        for i in "${!SSH_SENDERS[@]}";
        do
            sender=${SSH_SENDERS[$i]}
            array_index=$(((i + $DIFF_DEVICE) % ${#IP_RECEIVERS[@]}))
            ip_receiver=${IP_RECEIVERS[$array_index]}
            echo "      [INFO] Perform latency on sender $sender towards receiver with ip $ip_receiver."
            PERFORM_LATENCY_MEASUREMENT="ping -c $N_PING -i $PING_INTERVAL $ip_receiver | sed -n '2,$(($N_PING + 1))p' >> $REMOTE_WORKDIR/$REMOTE_LATENCY_RESULTS$sender.txt"
            $SSH_COMMAND $sender $PERFORM_LATENCY_MEASUREMENT &
        done

        echo "      [INFO] Wait for the end of this iteration measurements."
        sleep $(($WORKLOAD_DURATION+$DELTA_DURATION))
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
        $SCP_COMMAND $sender:$REMOTE_WORKDIR/$REMOTE_LATENCY_RESULTS$sender.txt $RESULTS_DIR/tmp_results

    done

    echo "[INFO] Format data into results file."
    for i in "${!SSH_SENDERS[@]}";
    do
        sender=${SSH_SENDERS[$i]}
        while IFS= read -r line; do
            latency=$(echo "$line" | awk '{print $7 $8}' | sed 's/time=//g')
            latency_in_ms=$(convert_to_milliseconds $latency)
            if [[ $latency_in_ms != -1 ]]; then
                echo "$N_DEVICES,$i,$latency_in_ms" >> $LATENCY_RESULTS
            fi
	    done < $RESULTS_DIR/tmp_results/$REMOTE_LATENCY_RESULTS$sender.txt
    done
	rm -r $RESULTS_DIR/tmp_results
}

if [ ${#SSH_SENDERS[@]} -ne ${#SSH_RECEIVERS[@]} ] || [ ${#SSH_SENDERS[@]} -ne ${#IP_RECEIVERS[@]} ]; then
    echo "[ERROR] The number of SSH senders, SSH receivers and receivers IP addresses must be the same."
    exit 1
fi

setup_local_workspace
setup_remote_workspace
measure_latency
clean_remote_workspace
