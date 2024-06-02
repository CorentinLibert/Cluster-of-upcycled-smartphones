#!/bin/bash

usage() {
    echo "USAGE: $0 [OPTIONS]"
    echo "OPTIONS:"
    echo "  MANDATORY:"
    echo "      -s|--server-ssh-infos <string>:         The list of SSH information of the cluster servers, separated by spaces (between quote) (e.g. \"localhost user@127.0.0.1)."
    echo "      -x|--scripts <string>:                  The scripts that have to be run between \"cpu\", \"ram\", \"disk\" and \"network\#. Several choices have to be separated by a space (between quote, e.g. \"cpu ram\"). At least one."
    echo "      -f|--filename:                          The list of the filename for each script. You should conserve the same order as for the scripts."
    echo ""
    echo "  OPTIONAL:"
    echo "      -a|--agent-ssh-infos <string>:          The list of SSH information of the cluster agents, separated by spaces (between quote) (e.g. \"localhost user@127.0.0.1)."
    echo "      -c|--count  <integer>:                  The number of measurements taken at an interval of 1 second. (default 40)"
    echo "      -i|--iterations <integer>:              The number of iterations. (default 5)"
    echo "      --filesystem <string>:                  The filesystem to monitor. Mandatory for script \"disk\")."
    echo "      --interface <string>:                   The network interface to monitor, either \"eth0\" or \"wlan0\". Mandatory for script \"network\")."
    echo "      --ubuntu <string>:                      The list of SSH informations of device under \"ubuntu\" (default \"alpine\"). Needed for ubuntu device when network script set."
    echo "      --wrk-path <string>:                    The path to wrk. If not empty, a workload will be generated."
    echo "      --wrk-script <string>:                  The path to the lua script used by wrk to generate the requests. Mandatory if wrk-path given."
    echo "      --cluster-entrypoint <string>:          The entrypoint of the cluster, in the format \"ip:port\". Mandatory if wrk-path given."
    echo "      -r|--reset:                             If this flag is set, the results will overwrite existing data in result file. Otherwise, results are appended."
    echo "      --n-devices                             The number of devices in the cluster. It is added to the results."
    echo "      --note:                             Additional informations about the experiment that should be added as a column in the results."
}

SERVER_SSH_INFOS=""
AGENT_SSH_INFOS=""
SCRIPTS=""
N_ITER=5
COUNT=40
FILESYSTEM=""
SCRIPT_INTERFACE=""
UBUNTU=""
WRK_PATH=""
WRK_SCRIPT=""
CLUSTER_ENTRYPOINT=""
RESET=0
FILENAME=""
N_DEV=""
NOTE=""


while [ $# -gt 0 ]
do
    case "$1" in
        -s|--server-ssh-infos) 
            read -a SERVER_SSH_INFOS <<< "$2";
            shift 2;;
        -a|--agent-ssh-infos)
            read -a AGENT_SSH_INFOS <<< "$2";
            shift 2;;
        -x|--scripts)
            read -a SCRIPTS <<< "$2";
            shift 2;;
        -c|--count)
            COUNT=$2;
            shift 2;;
        -i|--iterations)
            N_ITER=$2;
            shift 2;;
        --filesystem)
            FILESYSTEM=$2;
            shift 2;;
        --interface)
            INTERFACE=$2;
            shift 2;;
        --ubuntu)
            read -a UBUNTU <<< "$2"
            shift 2;;
        --wrk-path)
            WRK_PATH=$2;
            shift 2;;
        --wrk-script)
            WRK_SCRIPT=$2;
            shift 2;;
        --cluster-entrypoint)
            CLUSTER_ENTRYPOINT=$2;
            shift 2;;
        -r|--reset)
            RESET=1;
            shift 1;;
        -f|--filename)
            read -a FILENAME <<< "$2";
            shift 2;;
        --n-devices)
            N_DEV=$2;
            shift 2;;
        --note)
            NOTE=$2;
            shift 2;;
        -h|--help)
            usage;
            exit 0;;
        *)
            echo "[ERROR] Wrong flag $1";
            usage;
            exit 1;;
    esac
done

SSH_INFOS=( "${SERVER_SSH_INFOS[@]}" "${AGENT_SSH_INFOS[@]}" )

# Some Variables
WRK_TMP_START=""
WRK_TMP_END=""
# Local
WORKDIR="$(dirname $0)"
RESULTS_DIR="$WORKDIR/results"

# Remote
REMOTE_WORKDIR="~/remote_workspace_$((RANDOM))$((RANDOM))"
REMOTE_SCRIPT_DIR=$REMOTE_WORKDIR"/scripts"
REMOTE_RESULTS_DIR=$REMOTE_WORKDIR"/results"

# Commands
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q"

contains() {
    VALUE=$1
    ARRAY=("${@:2}")
    for v in ${ARRAY[@]}; do
        if [ "$v" == "$VALUE" ]; then
            echo 1
            return
        fi
    done
    echo 0
}

setup_remote_workspace() {
    echo "[INFO] Setup remote workspace."
    for ssh_info in ${SSH_INFOS[@]}; do
        $SSH_COMMAND $ssh_info "mkdir -p $REMOTE_WORKDIR; mkdir -p $REMOTE_SCRIPT_DIR; mkdir -p $REMOTE_RESULTS_DIR"
        # Copy scripts to remote
        for script in ${SCRIPTS[@]}; do
            echo "  [INFO] Copy script $script to device $ssh_info."
            $SCP_COMMAND "./scripts/"$script"_usage_script.sh" $ssh_info:$REMOTE_SCRIPT_DIR
        done
        # Result files are created by the corresponding script
    done
}

setup_local_workspace() {
    echo "[INFO] Setup local workspace."
    mkdir -p $RESULTS_DIR

    for filename in ${FILENAME[@]}; do
        if [ $RESET -eq 1 ]; then
            echo "  [INFO] Remove previous result file: $filename."
            rm -f $RESULTS_DIR/$filename
        fi
    done
}

clean_remote_workspace() {
    echo "[INFO] Clean remote workspace"
    for ssh_info in ${SSH_INFOS[@]}; do
        echo "  [INFO] Clean remote workspace on $ssh_info."
        $SSH_COMMAND $ssh_info "rm -r $REMOTE_WORKDIR"
    done
}

run_benchmark() {
    # Start scripts
    echo "[INFO] Run benchmark"
    for n_iter in $(seq $N_ITER); do
        echo "  [INFO] Iteration $n_iter/$N_ITER."
        [[ $n_iter == 1 ]] && script_init=1 || script_init=0
        for ssh_info in ${SSH_INFOS[@]}; do
            for i in ${!SCRIPTS[@]}; do
                script=${SCRIPTS[$i]}
                filename=${FILENAME[$i]}
                echo "      [INFO] Start script $script on $ssh_info."
                if [ $script == "cpu" ]; then
                    $SSH_COMMAND $ssh_info $REMOTE_SCRIPT_DIR"/"$script"_usage_script.sh $COUNT $REMOTE_RESULTS_DIR/$filename $script_init" &
                elif [ $script == "ram" ]; then
                    $SSH_COMMAND $ssh_info $REMOTE_SCRIPT_DIR"/"$script"_usage_script.sh $COUNT $REMOTE_RESULTS_DIR/$filename $script_init" &
                elif [ $script == "disk" ]; then
                    $SSH_COMMAND $ssh_info $REMOTE_SCRIPT_DIR"/"$script"_usage_script.sh $COUNT $FILESYSTEM $REMOTE_RESULTS_DIR/$filename $script_init" &
                elif [ $script == "network" ]; then
                    if [ $(contains "$ssh_info" "${UBUNTU[@]}") -eq 1 ]; then
                        if [ $INTERFACE == "eth0" ]; then
                            $SSH_COMMAND $ssh_info $REMOTE_SCRIPT_DIR"/"$script"_usage_script.sh $COUNT enp1s0 ubuntu $REMOTE_RESULTS_DIR/$filename $script_init" &
                        elif [ $INFERFACE == "wlan0" ]; then
                            $SSH_COMMAND $ssh_info $REMOTE_SCRIPT_DIR"/"$script"_usage_script.sh $COUNT wlp0s20f3 ubuntu $REMOTE_RESULTS_DIR/$filename $script_init" &
                        fi
                    else
                        $SSH_COMMAND $ssh_info $REMOTE_SCRIPT_DIR"/"$script"_usage_script.sh $COUNT $INTERFACE alpine $REMOTE_RESULTS_DIR/$filename $script_init" &
                    fi
                fi
            done
        done

        if [[ -n $WRK_PATH ]]; then
            # Wait 5 seconds before starting workload
            sleep 5
            echo "[INFO] Generate workload with wrk."
            timestamp_start=$(date +%s)
            duration=$(($COUNT -20))
            if [[ -n $WRK_SCRIPT ]]; then
                wrk_script="-s "$WRK_SCRIPT
            fi
            $WRK_PATH -c20 -d"$duration"s -t8 -a -r -R 1000 $wrk_script http://$CLUSTER_ENTRYPOINT #> /dev/null
            timestamp_end=$(date +%s)
            sleep 20
            WRK_TMP_START=$WRK_TMP_START" "$timestamp_start
            WRK_TMP_END=$WRK_TMP_END" " $timestamp_end
        else
            sleep $(($COUNT + 5))
            WRK_TMP_START=$WRK_TMP_START" -1"
            WRK_TMP_END=$WRK_TMP_END" -1"
        fi
    done
}

post_benchmark() {
    echo "[INFO] Run post benchmark."
    tmp_result_dir=$RESULTS_DIR"/tmp"
    mkdir -p $tmp_result_dir

    for ssh_info in ${SSH_INFOS[@]}; do
        # Is a server or an agent
        if [ $(contains "$ssh_info" "${SERVER_SSH_INFOS[@]}") -eq 1 ]; then
            is_server=1
        else
            is_server=0
        fi
        # Retrieve files
        for filename in ${FILENAME[@]}; do
            echo "[INFO] Retrieve $filename from $ssh_info."
            basename="${filename%.*}"
            extension="${filename##*.}"
            local_tmp_file_path=$tmp_result_dir/$basename$ssh_info.$extension
            $SCP_COMMAND $ssh_info:$REMOTE_RESULTS_DIR/$filename $local_tmp_file_path

            # If result file does not exist, create it with the header.
            if [ ! -f "$RESULTS_DIR/$filename" ]; then
                awk 'NR == 1 {print $0",ssh_info,is_server,iteration,workload_start,workload_end,n_devices,note"}' $local_tmp_file_path > $RESULTS_DIR/$filename
            fi

            # Append formatted results
            wrk_tmp_s=($WRK_TMP_START)
            wrk_tmp_e=($WRK_TMP_END)
            for i in $(seq 0 $((N_ITER-1))); do
                awk -v count=$COUNT -v si=$ssh_info -v srv=$is_server -v i=$i -v wrk_s=${wrk_tmp_s[$i]} -v wrk_e=${wrk_tmp_e[$i]} -v n_dev="$N_DEV" -v note="$NOTE" 'NR > (i*count)+1 && NR <= ((i+1)*count)+1 {print $0","si","srv","i","wrk_s","wrk_e","n_dev","note}' $local_tmp_file_path >> $RESULTS_DIR/$filename
            done
        done
    done
    rm -r $tmp_result_dir
}


# Check args
if [ ${#SERVER_SSH_INFOS[@]} -eq 0 ]; then
    echo "[ERROR] No SSH informations for server were given."
    exit 1
fi

if [ ${#SCRIPTS[@]} -ge 1 ]; then
    for script in ${SCRIPTS[@]}; do
        if [ $script != "cpu" ] && [ $script != "ram" ] && [ $script != "disk" ] && [ $script != "network" ]; then
            echo "[ERROR] Wrong script value: $script."
            exit 1
        fi
    done
else
    echo "[ERROR] No script selected. At least one script should be selected."
    exit 1
fi

if [ ${#SCRIPTS[@]} -ne ${#FILENAME[@]} ]; then
    echo "[ERROR] The number of filename does not correspond to the number of selected script."
    exit 1
fi

if [ $(contains "disk" $SCRIPTS) -eq 1 ] && [ -n $FILESYSTEM ]; then 
    echo "[ERROR] Disk script selected, but no filesystem provided."
    exit 1
fi

if [ $(contains "network" $SCRIPTS) -eq 1 ] && [ -n $INFERFACE ]; then 
    echo "[ERROR] Network script selected, but no interface provided."
    exit 1
fi

if [ ! -z $WRK_PATH ] && ([ -z $WRK_SCRIPT ] || [ -z $CLUSTER_ENTRYPOINT ]); then
    echo "[ERROR] WRK path provided, but no WRK script or cluster entrypoint provided."
    exit 1
fi
if [ ! -z $WRK_PATH ] && [ ! -f "$WRK_PATH" ]; then
    echo "[ERROR] WRK path provided does not exist."
    exit 1
fi
if [ ! -z $WRK_SCRIPT ] && [ ! -f "$WRK_SCRIPT" ]; then
    echo "[ERROR] WRK script path provided does not exist."
    exit 1
fi

setup_remote_workspace
setup_local_workspace
run_benchmark
post_benchmark "0 0"
clean_remote_workspace