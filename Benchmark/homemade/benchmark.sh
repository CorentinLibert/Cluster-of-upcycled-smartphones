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
SSH_HOSTNAME="172.16.42.1"
SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
SCP_COMMAND="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# TODO: Add a sshkey path options

# Benchmark configuration
DURATION=10
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
	$SSH_COMMAND $SSH_USERNAME@$SSH_HOSTNAME <<-EOF 
	> $REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_RESULT_NAME
	EOF
	# Copy the script to retrieve CPU usage data (if any)
	$SCP_COMMAND  $CPU_USAGE_LOCAL_SCRIPT_PATH $SSH_USERNAME@$SSH_HOSTNAME:$REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_SCRIPT_NAME
}

setup() {
	# Create tmp directory on remote device
	$SSH_COMMAND $SSH_USERNAME@$SSH_HOSTNAME <<-EOF 
	mkdir $REMOTE_WORK_DIR
	EOF
	# TODO: Check if CPU_load option
	if [ -n "$CPU_USAGE_LOCAL_SCRIPT_PATH" ]; then 
    	setup_cpu_usage
	fi
}

run_pre_script() {
	# TODO: Check if CPU_load option
	# Run CPU usage script
	if [ -n "$CPU_USAGE_LOCAL_SCRIPT_PATH" ]; then 
		$SSH_COMMAND $SSH_USERNAME@$SSH_HOSTNAME <<-EOF 
		sh $REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_SCRIPT_NAME $REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_RESULT_NAME $DURATION
		EOF
    fi
}

# run_script() {

# }

run_post_script() {
	mkdir -p $SCRIPT_DIR/results
	# Retrieve data for CPU usage and build graph from it
	if [ -n "$CPU_USAGE_LOCAL_SCRIPT_PATH" ]; then 
		mkdir -p $CPU_USAGE_LOCAL_RESULT_PATH
		$SCP_COMMAND $SSH_USERNAME@$SSH_HOSTNAME:$REMOTE_WORK_DIR/$CPU_USAGE_REMOTE_RESULT_NAME $CPU_USAGE_LOCAL_RESULT_PATH
		mkdir -p $GRAPH_DIR_PATH
		python3 $CPU_GRAPH_SCRIPT_PATH $CPU_USAGE_LOCAL_RESULT_PATH $GRAPH_DIR_PATH
    fi
}

configuration
# setup
# run_pre_script
# run_script
run_post_script