#!/bin/bash

usage() {
    echo "USAGE: $0 [OPTIONS]"
    echo "OPTIONS:"
    echo "      --sender-ssh <string>:                  The list of SSH information of the senders, formatted as a string of username@hostname separeted by spaces. For example: \"user@192.168.88.2 admin@192.168.88.3\"."
    echo "      --sender-types <string>:                The list of the types of the senders (order should correspond to sender-ssh)."
    echo "      --receiver-ssh <string>:                The list of SSH information of the receivers, formatted as a string of username@hostname separeted by spaces. For example: \"user@192.168.88.2 admin@192.168.88.3\"."
    echo "      --receiver-types <string>:              The list of the types of the receivers (order should correspond to receiver-ssh)."
    echo "      --iterations <int>:                        The number of time the experiment should be run. (default: 5)"
    echo "      --reverse:                              If this flag is set, the senders and receivers are inversed. (default: False)"
    echo "      --count <int>:                          The number of ping replies before stopping. (default: 10)"
    echo "      --omit <int>:                           The number of first seconds of the test that should be omitted. (default: 0)"
    echo "      --number-devices <int>:                 The number of devices connected to the medium (directly written the results)"
    echo "      --with-workload:                        If this flag is set, a random workload is generate between pair for devices with iperf3. (default: False)"
    echo "      --medium <string>:                      The networking medium."
    echo "      --result-dir <string>:                  The path toward the results should be stored."
    echo "      --verbose:                              If this flag is set, print more informations during execution."
    echo "      -h|--help:                              Print this message and exit."
}

SENDER_SSH=()
SENDER_TYPES=()
RECEIVER_SSH=()
RECEIVER_TYPES=()
RECEIVER_IPS=()
ITERATIONS=5
REVERSE=0
COUNT=10
OMIT=0
NUMBER_DEVICES=0
WORKLOAD=0
MEDIUM=""
RESULTS_DIR=""
VERBOSE=0

# Commands
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# Variables
REMOTE_WORKDIR="~/remote_workspace_$((RANDOM))$((RANDOM))"
FILE_BASENAME="latency_raw"
FILE_EXTENSION=".txt"

reverse_senders_receivers() {
    TMP_SSH=(${SENDER_SSH[@]})
    TMP_TYPES=(${SENDER_TYPES[@]})
    SENDER_SSH=(${RECEIVER_SSH[@]})
    SENDER_TYPES=(${RECEIVER_TYPES[@]})
    RECEIVER_SSH=(${TMP_SSH[@]})
    RECEIVER_TYPES=(${TMP_TYPES[@]})
}

retrieve_receiver_ips() {
    for receiver in "${RECEIVER_SSH[@]}"; do
        ip="${receiver#*@}"
        RECEIVER_IPS+=("$ip")
    done
}

create_remote_workspace() {
    echo "[INFO] Create remote workspace."
    for i in ${!SENDER_SSH[@]}; do
        sender=${SENDER_SSH[i]}
        receiver=${RECEIVER_SSH[i]}
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $sender"
        fi
        # On sender
        $SSH_COMMAND $sender "mkdir -p $REMOTE_WORKDIR; echo $'# MEDIUM=$MEDIUM\n# SENDER=$sender\n# SENDER_TYPE=${SENDER_TYPES[i]}\n# RECEIVER=$receiver\n# RECEIVER_TYPE=${RECEIVER_TYPES[i]}\n# ITERATIONS=$ITERATIONS\n# REVERSE=$REVERSE\n# COUNT=$COUNT\n# OMIT=$OMIT\n# WORKLOAD=$WORKLOAD\n# NUMBER_DEVICES=$NUMBER_DEVICES\n# PARALLEL_CONNECTIONS=${#SENDER_SSH[@]}' > $REMOTE_WORKDIR/sender_${FILE_BASENAME}_${sender}_to_${receiver}_${NUMBER_DEVICES}${FILE_EXTENSION}"
        # On receiver
        $SSH_COMMAND $receiver "mkdir -p $REMOTE_WORKDIR; echo $'# MEDIUM=$MEDIUM\n# SENDER=$sender\n# SENDER_TYPE=${SENDER_TYPES[i]}\n# RECEIVER=$receiver\n# RECEIVER_TYPE=${RECEIVER_TYPES[i]}\n# ITERATIONS=$ITERATIONS\n# REVERSE=$REVERSE\n# COUNT=$COUNT\n# OMIT=$OMIT\n# WORKLOAD=$WORKLOAD\n# NUMBER_DEVICES=$NUMBER_DEVICES\n# PARALLEL_CONNECTIONS=${#SENDER_SSH[@]}' > $REMOTE_WORKDIR/receiver_${FILE_BASENAME}_${receiver}_${NUMBER_DEVICES}${FILE_EXTENSION}"
    done
}

create_local_workspace() {
    echo "[INFO] Create local workspace."
    mkdir -p $RESULTS_DIR
}

remove_remote_workspace() {
    echo "[INFO] Remove remote workspace."
    for sender in ${SENDER_SSH[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on sender $sender"
        fi
        $SSH_COMMAND $sender "rm -rf $REMOTE_WORKDIR"
    done
    for receiver in ${RECEIVER_SSH[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on receiver $receiver"
        fi
        $SSH_COMMAND $receiver "rm -rf $REMOTE_WORKDIR"
    done
}


start_iperf3_servers() {
    echo "[INFO] Start iperf3 servers."
    for receiver in ${RECEIVER_SSH[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $receiver"
        fi
        $SSH_COMMAND $receiver "iperf3 -s -D --logfile $REMOTE_WORKDIR/receiver_${FILE_BASENAME}_${receiver}_${NUMBER_DEVICES}${FILE_EXTENSION}"
    done
}

stop_iperf3_servers() {
    echo "[INFO] Stop iperf3 servers."
    for receiver in ${RECEIVER_SSH[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $receiver"
        fi
        $SSH_COMMAND $receiver 'kill $(pidof iperf3)'
    done
}

start_iperf3_workload() {
    echo "[INFO] Start iperf3 workload on senders."
    for i in ${!SENDER_SSH[@]}; do
        sender=${SENDER_SSH[i]}
        receiver=${RECEIVER_SSH[i]}
        receiver_ip=${RECEIVER_IPS[i]}
        if [ $VERBOSE -eq 1 ]; then
            echo "      from $sender to $receiver"
        fi
        $SSH_COMMAND $sender "iperf3 -c $receiver_ip --time 0 > /dev/null" &
    done
}

stop_iperf3_workload() {
    echo "[INFO] Stop iperf3 workload on senders."
    for sender in ${SENDER_SSH[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $sender"
        fi
        $SSH_COMMAND $sender 'kill $(pidof iperf3)'
    done
}

perform_measurement() {
    echo "[INFO] Perform measurement."
    for iter in $(seq 1 $ITERATIONS); do
        echo "   Iterations: $iter/$ITERATIONS"
        if [ $WORKLOAD -eq 1 ]; then
            start_iperf3_servers
            start_iperf3_workload
        fi
        (for i in ${!SENDER_SSH[@]}; do
            sender=${SENDER_SSH[i]}
            receiver=${RECEIVER_SSH[i]}
            receiver_ip=${RECEIVER_IPS[i]}
            if [ $VERBOSE -eq 1 ]; then
                echo "      from $sender to $receiver"
            fi
            $SSH_COMMAND $sender "echo $'\n# ITERATION $iter\n' >> $REMOTE_WORKDIR/sender_${FILE_BASENAME}_${sender}_to_${receiver}_${NUMBER_DEVICES}${FILE_EXTENSION}; ping $receiver_ip -c $COUNT >> $REMOTE_WORKDIR/sender_${FILE_BASENAME}_${sender}_to_${receiver}_${NUMBER_DEVICES}${FILE_EXTENSION}" &
        done
        wait
        )
        if [ $WORKLOAD -eq 1 ]; then
            stop_iperf3_workload
            stop_iperf3_servers
        fi
        sleep 5
    done
}

retrieve_results() {
    echo "[INFO] Retrieve remote results."
    for i in ${!SENDER_SSH[@]}; do
            sender=${SENDER_SSH[i]}
            receiver=${RECEIVER_SSH[i]}
        if [ $VERBOSE -eq 1 ]; then
            echo "      from sender $sender"
        fi
        $SCP_COMMAND $sender:$REMOTE_WORKDIR/sender_${FILE_BASENAME}_${sender}_to_${receiver}_${NUMBER_DEVICES}${FILE_EXTENSION} $RESULTS_DIR
        if [ $VERBOSE -eq 1 ]; then
            echo "      from receiver $receiver"
        fi
        $SCP_COMMAND $receiver:$REMOTE_WORKDIR/receiver_${FILE_BASENAME}_${receiver}_${NUMBER_DEVICES}${FILE_EXTENSION} $RESULTS_DIR
    done
}

# ======= Arguments Parsing ======= #

while [ $# -gt 0 ]
do
    case "$1" in
        --sender-ssh) 
            read -a SENDER_SSH <<< $2;
            shift 2;;
        --sender-types)
            read -a SENDER_TYPES <<< $2;
            shift 2;;
        --receiver-ssh)
            read -a RECEIVER_SSH <<< $2;
            shift 2;;
        --receiver-types)
            read -a RECEIVER_TYPES <<< $2;
            shift 2;;
        --iterations)
            ITERATIONS=$2;
            shift 2;;
        --reverse)
            REVERSE=1;
            shift 1;;
        --count)
            COUNT=$2;
            shift 2;;
        --omit)
            OMIT=$2;
            shift 2;;
        --number-devices)
            NUMBER_DEVICES="$2"
            shift 2;;
        --medium)
            MEDIUM="$2"
            shift 2;;
        --with-workload)
            WORKLOAD=1;
            shift 1;;
        --result-dir)
            RESULTS_DIR="$2";
            shift 2;;
        --verbose)
            VERBOSE=1;
            shift 1;;
        -h|--help)
            usage;
            exit 0;;
        *)
            echo "[ERROR] Wrong flag $1";
            usage;
            exit 1;;
    esac
done

# Reverse senders and receivers
if [ $REVERSE -eq 1 ]; then
    reverse_senders_receivers
fi

# Retrieve receiver ips
retrieve_receiver_ips

# Add the number of omit to count
COUNT=$(($COUNT+$OMIT))

echo "SENDER_SSH: ${SENDER_SSH[@]}"
echo "SENDER_TYPES: ${SENDER_TYPES[@]}"
echo "RECEIVER_SSH: ${RECEIVER_SSH[@]}"
echo "RECEIVER_TYPES: ${RECEIVER_TYPES[@]}"
echo "RECEIVER_IPS: ${RECEIVER_IPS[@]}"
echo "ITERATIONS: $ITERATIONS"
echo "REVERSE: $REVERSE"
echo "COUNT: $COUNT"
echo "OMIT: $OMIT"
echo "WORKLOAD: $WORKLOAD"
echo "MEDIUM: $MEDIUM"
echo "NUMBER_DEVICES: $NUMBER_DEVICES"
echo "RESULTS_DIR: $RESULTS_DIR"

# ======= Check Arguments ======= #

if [ ${#SENDER_SSH[@]} -eq 0 ] || ([ ${#SENDER_SSH[@]} -ge 1 ] && [ -z ${SENDER_SSH[0]} ]); then
    echo "[ERROR] No SSH information for the senders has been given."
    exit 1
fi

if [ ${#SENDER_TYPES[@]} -eq 0 ] || ([ ${#SENDER_TYPES[@]} -ge 1 ] && [ -z ${SENDER_TYPES[0]} ]); then
    echo "[ERROR] No type information for the senders has been given."
    exit 1
fi

if [ ${#RECEIVER_SSH[@]} -eq 0 ] || ([ ${#RECEIVER_SSH[@]} -ge 1 ] && [ -z ${RECEIVER_SSH[0]} ]); then
    echo "[ERROR] No SSH information for the receivers has been given."
    exit 1
fi

if [ ${#RECEIVER_TYPES[@]} -eq 0 ] || ([ ${#RECEIVER_TYPES[@]} -ge 1 ] && [ -z ${RECEIVER_TYPES[0]} ]); then
    echo "[ERROR] No type information for the receivers has been given."
    exit 1
fi

if [ ${#RECEIVER_IPS[@]} -eq 0 ] || ([ ${#RECEIVER_IPS[@]} -ge 1 ] && [ -z ${RECEIVER_IPS[0]} ]); then
    echo "[ERROR] No ips information for the receviers could be retrieved. SSH format should be of the form \"username@ip\""
    exit 1
fi

if [ ${#SENDER_SSH[@]} -ne ${#RECEIVER_SSH[@]} ]; then
    echo "[ERROR] The number of senders and receivers are different."
    exit 1
fi

if [ ${#SENDER_SSH[@]} -ne ${#SENDER_TYPES[@]} ]; then
    echo "[ERROR] The number of sender SSH informations and sender type informations are different."
    exit 1
fi

if [ ${#RECEIVER_SSH[@]} -ne ${#RECEIVER_TYPES[@]} ]; then
    echo "[ERROR] The number of receiver SSH informations and receiver type informations are different."
    exit 1
fi

if [ ${#RECEIVER_SSH[@]} -ne ${#RECEIVER_IPS[@]} ]; then
    echo "[ERROR] The number of receiver SSH informations and receiver IPs retrieved are different. Not all receiver IPs could have been retrieved."
    exit 1
fi

if [ -z $RESULTS_DIR ]; then
    echo "[ERROR] No path towards the result file has been given."
    exit 1
fi

if [ ${#SERVER_SSH_INFOS[@]} -ne ${#CLIENT_SSH_INFOS[@]} ]; then
    echo "[ERROR] The number of servers and clients are different."
    exit 1
fi

create_local_workspace
create_remote_workspace
# if [ $WORKLOAD -eq 1 ]; then
#     start_iperf3_servers
# fi
perform_measurement
# if [ $WORKLOAD -eq 1 ]; then
#     stop_iperf3_servers
# fi
retrieve_results
remove_remote_workspace