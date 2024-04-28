#!/bin/bash

# 1. Connect in ssh to the smarthpone
# 3. Run script to get CPU usage in a local file
# 4. Retrieve CPU usage

# TODO: Add a force option (careful with it)

# General configuration
SILENT=1
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) # See: https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script

# SSH configuration
SSH_USERNAME="pptc"
SSH_HOSTNAME_LIST="192.168.88.4 192.168.88.5"
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# TODO: Add a sshkey path options

# Benchmark configuration
DURATION=20
REMOTE_WORK_DIR="/tmp/local_measurements"
CPU_USAGE_LOCAL_SCRIPT_PATH="script_cpu_usage.sh"
CPU_USAGE_REMOTE_SCRIPT_NAME="cpu_usage_script.sh"
CPU_USAGE_REMOTE_RESULT_NAME="cpu_usage_results.txt"

# Post script configuration
CPU_GRAPH_SCRIPT_PATH=$SCRIPT_DIR"/cpu_usage_graph.py"
CPU_USAGE_LOCAL_RESULT_PATH=$SCRIPT_DIR"/results/cpu_usage"
GRAPH_DIR_PATH=$SCRIPT_DIR"/graphs"

configuration() {
	if [ $SILENT -eq 1 ]; then
		SSH_COMMAND+=" -q"
		SCP_COMMAND+=" -q"
	fi
}

setup_cpu_usage() {
    # New measurement file
	SSH_HOSTNAME=$1
	echo "Setup CPU USAGE for $SSH_HOSTNAME"
	$SSH_COMMAND $SSH_USERNAME@$SSH_HOSTNAME <<-EOF 
	> $REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_RESULT_NAME
	EOF
	# Copy the script to retrieve CPU usage data (if any)
	$SCP_COMMAND  $CPU_USAGE_LOCAL_SCRIPT_PATH $SSH_USERNAME@$SSH_HOSTNAME:$REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_SCRIPT_NAME
}

setup() {
	# Create tmp directory on remote device
	for SSH_HOSTNAME in $SSH_HOSTNAME_LIST; do
		echo "Setup for $SSH_HOSTNAME"
		$SSH_COMMAND $SSH_USERNAME@$SSH_HOSTNAME <<-EOF 
		mkdir -p $REMOTE_WORK_DIR
		EOF
		# TODO: Check if CPU_load option
		if [ -n "$CPU_USAGE_LOCAL_SCRIPT_PATH" ]; then 
			setup_cpu_usage $SSH_HOSTNAME
		fi
	done
}

run_pre_script() {
	# TODO: Check if CPU_load option
	# Run CPU usage script
	for SSH_HOSTNAME in $SSH_HOSTNAME_LIST; do
		if [ -n "$CPU_USAGE_LOCAL_SCRIPT_PATH" ]; then
			echo "Run CPU Usage Pre Script for $SSH_HOSTNAME"
			$SSH_COMMAND $SSH_USERNAME@$SSH_HOSTNAME "sh $REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_SCRIPT_NAME $REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_RESULT_NAME $DURATION" &
		fi
	done
}

run_script() {
	~/Documents/TFE/npf/build/wrk2-tbarbette/wrk -c20 -d15s -t8 -a -r -R 500 -s /home/corentin/Documents/TFE/TFE_Git/Benchmark/wrk/simple_script.lua http://192.168.88.4:31000 #> /dev/null
	sleep 10
}

run_post_script() {
	mkdir -p $SCRIPT_DIR/results
	# Retrieve data for CPU usage and build graph from it
	if [ -n "$CPU_USAGE_LOCAL_SCRIPT_PATH" ]; then 
		mkdir -p $CPU_USAGE_LOCAL_RESULT_PATH
		for SSH_HOSTNAME in $SSH_HOSTNAME_LIST; do
			echo "Run Post Script for $SSH_HOSTNAME"
			IP_ID=$(echo $SSH_HOSTNAME | awk -F'.' '{print $4}') # Last byte of the IP address, used as ID
			$SCP_COMMAND $SSH_USERNAME@$SSH_HOSTNAME:$REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_RESULT_NAME $CPU_USAGE_LOCAL_RESULT_PATH/cpu_usage_results_$IP_ID.txt
		done
		$SSH_COMMAND $SSH_USERNAME@$SSH_HOSTNAME "rm -rf $REMOTE_WORK_DIR"
		mkdir -p $GRAPH_DIR_PATH
		python3 $CPU_GRAPH_SCRIPT_PATH $CPU_USAGE_LOCAL_RESULT_PATH $GRAPH_DIR_PATH
    fi
}

configuration
setup
run_pre_script
run_script
run_post_script