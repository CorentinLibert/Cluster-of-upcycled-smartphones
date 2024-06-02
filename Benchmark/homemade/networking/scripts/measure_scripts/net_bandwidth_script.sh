#!/bin/bash

usage() {
    echo "USAGE: $0 [OPTIONS]"
    echo "OPTIONS:"
    echo "  MANDATORY:"
    echo "      -s|--server-ssh-infos [string]:         The list of SSH information of the cluster servers, formatted as a string of username@hostname separeted by spaces. For example: \"user@192.168.88.2 admin@192.168.88.3\"."
    echo "      -c|--client-ssh-infos [string]:         The list of SSH information of the cluster clients, formatted as a string of username@hostname separeted by spaces. For example: \"user@192.168.88.2 admin@192.168.88.3\"."
    echo "      -d|--results-dir [string]:              The path to the result directory."
    echo ""
    echo "  OPTIONAL:"
    echo "      -i|--iteration [int]:                   The total number of iterations that must be performed (default: 5)."
    echo "      --iperf3-args [string]:                 The arguments that should be given to iperf3 by the client."
    echo "      -r|--reset:                             If this flag is set, the results will overwrite existing data in result file. Otherwise, results are appended."
    echo "      -v|--verbose:                           If this flag is set, run in verbose mode."
    echo "      -h|--help:                              Print this message and exit."
}

SERVER_SSH_INFOS=""
CLIENT_SSH_INFOS=""
RESULTS_DIR=""
IPERF3_ARGS=""
RESET=0
VERBOSE=0
ITERATIONS=5

# Commands
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

# Variables
REMOTE_WORKDIR="~/remote_workspace_$((RANDOM))$((RANDOM))"
FILE_BASENAME="bandwidth_raw_results_"
FILE_EXTENSION=".txt"


create_remote_workspace() {
    echo "[INFO] Create remote workspace."
    for i in ${!CLIENT_SSH_INFOS[@]}; do
        client=${CLIENT_SSH_INFOS[i]}
        server=${SERVER_SSH_INFOS[i]}
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $client"
        fi
        $SSH_COMMAND $client "mkdir -p $REMOTE_WORKDIR; echo $'### CLIENT_SSH_INFO=$client\n### SERVER_SSH_INFO=$server\n### IPERF3_ARGS=$IPERF3_ARGS\n### PARALLEL_CONN=${#CLIENT_SSH_INFOS[@]}' > $REMOTE_WORKDIR/$FILE_BASENAME$client$FILE_EXTENSION"
    done
}

create_local_workspace() {
    echo "[INFO] Create local workspace."
    mkdir -p $RESULTS_DIR
}

remove_remote_workspace() {
    echo "[INFO] Remove remote workspace."
    for client in ${CLIENT_SSH_INFOS[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $client"
        fi
        $SSH_COMMAND $client "rm -rf $REMOTE_WORKDIR"
    done
}

start_iperf3_servers() {
    echo "[INFO] Start iperf3 servers."
    for server in ${SERVER_SSH_INFOS[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $server"
        fi
        $SSH_COMMAND $server "iperf3 -s -D"
    done
}

stop_iperf3_server() {
    echo "[INFO] Stop iperf3 servers."
    for server in ${SERVER_SSH_INFOS[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      on $server"
        fi
        $SSH_COMMAND $server 'kill $(pidof iperf3)'
    done
}

retrieve_server_ips_from_ssh_infos() {
    SERVER_IPS=($(echo $SERVER_SSH_INFOS | tr ' ' '\n' | awk -F'@' '{print $2}'))
}

perform_measurement() {
    echo "[INFO] Perform measurement."
    for iteration in $(seq 1 $ITERATIONS); do
        echo "   Iterations: $iteration/$ITERATIONS"
        (for i in ${!CLIENT_SSH_INFOS[@]}; do
            client=${CLIENT_SSH_INFOS[i]}
            server=${SERVER_SSH_INFOS[i]}
            server_ip=${SERVER_IPS[i]}
            if [ $VERBOSE -eq 1 ]; then
                echo "      from $client to $server"
            fi
            $SSH_COMMAND $client "echo $'\n### ITERATION $iteration\n' >> $REMOTE_WORKDIR/$FILE_BASENAME$client$FILE_EXTENSION; iperf3 -c $server_ip $IPERF3_ARGS >> $REMOTE_WORKDIR/$FILE_BASENAME$client$FILE_EXTENSION" &
        done
        wait
        )
        sleep 5
    done
}

retrieve_results() {
    echo "[INFO] Retrieve remote results."
    for client in ${CLIENT_SSH_INFOS[@]}; do
        if [ $VERBOSE -eq 1 ]; then
            echo "      from $client"
        fi
        $SCP_COMMAND $client:$REMOTE_WORKDIR/$FILE_BASENAME$client$FILE_EXTENSION $RESULTS_DIR
    done
}

# ======= Arguments Parsing ======= #

while [ $# -gt 0 ]
do
    case "$1" in
        -s|--server-ssh-infos) 
            read -a SERVER_SSH_INFOS <<< $2;
            shift 2;;
        -c|--client-ssh-infos)
            read -a CLIENT_SSH_INFOS <<< $2;
            shift 2;;
        -d|--results-dir)
            RESULTS_DIR="$2";
            shift 2;;
        -i|--iteration)
            ITERATIONS=$2;
            shift 2;;
        --iperf3-args)
            IPERF3_ARGS="$2";
            shift 2;;
        -r|--reset)
            RESET=1;
            shift 1;;
        -v|--verbose)
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

echo "SERVER_SSH_INFOS: ${SERVER_SSH_INFOS[@]}"
echo "SERVER_SSH_INFOS: ${#SERVER_SSH_INFOS[@]}"
echo "CLIENT_SSH_INFOS: ${CLIENT_SSH_INFOS[@]}"
echo "ITERATIONS: $ITERATIONS"
echo "IPERF3_ARGS: $IPERF3_ARGS"
echo "IPERF3_ARGS: $IPERF3_ARGS"
echo "RESET: $RESET"
echo "VERBOSE: $VERBOSE"

# ======= Check Arguments ======= #

if [ ${#SERVER_SSH_INFOS[@]} -eq 0 ] || [ -z ${SERVER_SSH_INFOS[0]} ]; then
    echo "[ERROR] No SSH information for server has been given."
    exit 1
fi

if [ ${#CLIENT_SSH_INFOS[@]} -eq 0 ] || [ -z ${CLIENT_SSH_INFOS[0]} ]; then
    echo "[ERROR] No SSH information for client has been given."
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

retrieve_server_ips_from_ssh_infos
create_local_workspace
create_remote_workspace
start_iperf3_servers
perform_measurement
stop_iperf3_server
retrieve_results
remove_remote_workspace