#!/usr/bin/env bash

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# derive from SCRIPT_DIR
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"
WORKFLOWS_PATH="$SCRIPT_DIR/../submodules/workflows"

# constants
WORKFLOWS_REPOSITORY="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github workflows_repo)")"
PLAYBOOKS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths playbooks)")"
WORKFLOWS_PUSH_BRANCH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_workflows)"
WORKFLOWS_REPO="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github workflows_repo)"
PLAYBOOKS_PUSH_BRANCH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_playbooks)"
PLAYBOOKS_REPO="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github playbooks_repo)"
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths workflows)")"

#if [[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH" ]]; then
#  WORKFLOWS_PUSH_BRANCH="$(cat "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH")"
#else
#  WORKFLOWS_PUSH_BRANCH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_workflows)"
#fi

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# booking (action scripts currently echo parameters only)
BOOKING_DESCRIPTION="List, add, share or cancel bookings"
BOOKING_FLAGS=()
# list
BOOKING_LIST_DESCRIPTION="List active bookings"
BOOKING_LIST_FLAGS=(
  "all,a,Show all booking services,-,-"
  "date,d,Booking date (YYYY-MM-DD),-,$(date +%F)"
  "server,s,Server inventory name,-,-"
)
BOOKING_LIST_FLAGS_MANDATORY=""
# add
BOOKING_ADD_DESCRIPTION="Reserve a server for a specific time"
BOOKING_ADD_FLAGS=(
  "date,d,Booking date (YYYY-MM-DD),-,$(date +%F)"
  "duration,,Duration in hours,-,1"
  "server,s,Server inventory name,-,-"
  "shared,,Users to share the booking with (comma-separated),-,-"
  "start,,Start time (HH:MM),-,$(
    read -r hour minute < <(date '+%H %M')
    next_minutes=$(( (10#$hour * 60 + 10#$minute) / 5 * 5 + 5 ))
    printf '%02d:%02d' "$(( next_minutes / 60 % 24 ))" "$(( next_minutes % 60 ))"
  )"
)
BOOKING_ADD_FLAGS_MANDATORY="server,start"
# cancel
BOOKING_CANCEL_DESCRIPTION="Cancel an active or future booking"
BOOKING_CANCEL_FLAGS=(
  "booking,b,Booking ID to cancel (defaults to your next upcoming booking),-,-"
)
# Without flags select your next upcoming booking on the current booking service.
# Cancellation requires confirmation and follows the existing session handover rule.
BOOKING_CANCEL_FLAGS_MANDATORY=""
# share
BOOKING_SHARE_DESCRIPTION="Share your active or next booking"
BOOKING_SHARE_FLAGS=(
  "server,s,Server inventory name,-,-"
  "users,u,Users to add to the booking (comma-separated),-,-"
)
BOOKING_SHARE_FLAGS_MANDATORY="server,users"

# build
BUILD_DESCRIPTION="Project build using the workflow recipe"
BUILD_FLAGS=(
)

# delete
DELETE_DESCRIPTION="Deletes an artifact of your choice"
DELETE_FLAGS=(
)
# workflow
DELETE_WORKFLOW_DESCRIPTION="Deletes an existing user workflow"
DELETE_WORKFLOW_FLAGS=(
  "name,n,Workflow name,-,-"
)
DELETE_WORKFLOW_FLAGS_MANDATORY="name"
# playbook
DELETE_PLAYBOOK_DESCRIPTION="Deletes an existing user playbook"
DELETE_PLAYBOOK_FLAGS=(
  "name,n,Playbook name,-,-"
)
DELETE_PLAYBOOK_FLAGS_MANDATORY="name"

# examine 
EXAMINE_DESCRIPTION="System and device inspection"
EXAMINE_FLAGS=(
  "tools,t,Show installed tools,-,-"
  "servers,s,Show server list,-,-"
)

# get 
GET_DESCRIPTION="System and device information retrieval"
GET_FLAGS=(
)
# ip
GET_IP_DESCRIPTION="Get the IP address of a specific device"
GET_IP_FLAGS=(
  "device,d,Device index,-,-"
  "numa,n,Non-Uniform Memory Access (NUMA) index,-,-"
  "port,p,Port index,-,0"
  "type,t,Device type,accel|endata,endata"
)
GET_IP_FLAGS_MANDATORY="numa,device" #"numa,type,device,port"
# mac
GET_MAC_DESCRIPTION="Get the MAC address of a specific device"
GET_MAC_FLAGS=(
  "device,d,Device index,-,-"
  "numa,n,Non-Uniform Memory Access (NUMA) index,-,-"
  "port,p,Port index,-,0"
  "type,t,Device type,accel|endata,endata"
)
GET_MAC_FLAGS_MANDATORY="numa,device" #"numa,type,device,port"

# ifconfig 
IFCONFIG_DESCRIPTION="Data-plane network interface configuration"
IFCONFIG_FLAGS=(
)

# new
NEW_DESCRIPTION="Create a new playbook, project or workflow"
NEW_FLAGS=(
)
# playbook
NEW_PLAYBOOK_DESCRIPTION="Adds a new playbook to ${bold}$PLAYBOOKS_USER_PATH${normal}"
NEW_PLAYBOOK_FLAGS=(
  "name,n,Playbook name,-,-"
)
NEW_PLAYBOOK_FLAGS_MANDATORY="name"
# workflow
NEW_WORKFLOW_DESCRIPTION="Creates a new accelerated workflow in ${bold}$WORKFLOWS_USER_PATH${normal}"
NEW_WORKFLOW_FLAGS=(
  #"fork,f,Create GitHub fork of oreolag/workflows,-,-"
  "name,n,Workflow name,-,-"
  "template,t,Use existing workflow as template,-,-"
)
NEW_WORKFLOW_FLAGS_MANDATORY="name"

# program
PROGRAM_DESCRIPTION="Device programming"
PROGRAM_FLAGS=(
)

# run
RUN_DESCRIPTION="Accelerated application execution"
RUN_FLAGS=(
)
# playbook
RUN_PLAYBOOK_DESCRIPTION="Runs a playbook on the selected hosts"
RUN_PLAYBOOK_FLAGS=(
  "name,n,Playbook name,-,-"
  "hosts,H,Target host or group,-,local"
  "inventory,i,Use a custom inventory path,-,-"
  "vars,v,Extra variables (example: \"src=true value=10\"),-,-"
)
RUN_PLAYBOOK_FLAGS_MANDATORY="name"

# set
SET_DESCRIPTION="Devices and host configuration"
SET_FLAGS=(
)
# mtu
SET_MTU_DESCRIPTION="Set the Maximum Transmission Unit (MTU) for a data network interface"
SET_MTU_FLAGS=(
  "interface,i,Interface index (endata),-,-"
  "port,p,Interface port index,-,0"
  "remote,r,Also configure remote hosts when set to 1,0|1,0"
  "value,v,MTU value,1500-9000,1500"
)
SET_MTU_FLAGS_MANDATORY="interface,value"

# update
UPDATE_DESCRIPTION="Update odev to the latest release/main version"
UPDATE_FLAGS=(
  "main,m,Use main branch instead of release,-,-"
)

# validate
VALIDATE_DESCRIPTION="Infrastructure functionality assessment"
VALIDATE_FLAGS=(
)
# nccl
#VALIDATE_NCCL_DESCRIPTION="NVIDIA Collective Communications Library (NCCL) validation"
#VALIDATE_NCCL_FLAGS=(
#  "ngpus,g,Number of GPUs,1-8,1"
#  "nthreads,t,Threads per process,1-64,1"
#  "minbytes,b,Minimum message size,1B|4K|8M|1G,8M"
#  "maxbytes,e,Maximum message size,1B|4K|1G|16G,1G"
#  "iters,n,Timed iterations,1-1000,20"
#  "datatype,d,Specify which datatype to use,int8|half|bfloat16|float,float"
#  "stepfactor,f,Multiplication factor between sizes,2|4|8,2"
#)
#VALIDATE_NCCL_FLAGS_MANDATORY="ngpus,minbytes,maxbytes"

# GitHub
GH_DESCRIPTION="GitHub support for community repositories" #"Manage and share your workflows and playbooks"
GH_FLAGS=(
)
# push
GH_PUSH_DESCRIPTION="Pushes your changes to your GitHub fork"
GH_PUSH_FLAGS=(
  "workflow,w,Workflow name,-,-"
  "playbook,p,Playbook name,-,-"
)
GH_PUSH_FLAGS_MANDATORY=""
# pull
GH_PULL_DESCRIPTION="Fetches and merges community main and fork branches locally"
GH_PULL_FLAGS=(
  "workflows,w,${bold}$WORKFLOWS_REPO${normal}:${bold}$WORKFLOWS_PUSH_BRANCH${normal},-,-"
  "playbooks,p,${bold}$PLAYBOOKS_REPO${normal}:${bold}$PLAYBOOKS_PUSH_BRANCH${normal},-,-"
)
GH_PULL_FLAGS_MANDATORY=""
# pr
GH_PR_DESCRIPTION="Proposes your changes to the community repository"
GH_PR_FLAGS=(
  "workflow,w,Workflow name,-,-"
  "playbook,p,Playbook name,-,-"
)
GH_PR_FLAGS_MANDATORY=""
# diff
GH_DIFF_DESCRIPTION="Shows uncommitted changes to your workflow or playbook"
GH_DIFF_FLAGS=(
  "workflow,w,Workflow name,-,-"
  "playbook,p,Playbook name,-,-"
  "file,f,Workflow file name (optional),-,-"
)
GH_DIFF_FLAGS_MANDATORY=""

# workflows
workflows=()
for d in "$WORKFLOWS_PATH"/*/; do
  workflows+=("$(basename "$d")")
done

# source cmd_spec.sh for workflows
for wf in "${workflows[@]}"; do
  wf_i="$SCRIPT_DIR/../submodules/workflows/$wf/cmd_spec.sh"
  [[ -f "$wf_i" ]] && source "$wf_i"
done

# user workflows
workflows_user=()
if [[ -d "$WORKFLOWS_USER_PATH" ]]; then
  for d in "$WORKFLOWS_USER_PATH"/*; do
    [[ -d "$d" ]] || continue
    workflows_user+=("$(basename "$d")")
  done
fi

# source cmd_spec.sh for user workflows not in workflows
for wf in "${workflows_user[@]}"; do
  [[ " ${workflows[*]} " =~ " $wf " ]] && continue
  wf_i="$WORKFLOWS_USER_PATH/$wf/cmd_spec.sh"
  [[ -f "$wf_i" ]] && source "$wf_i"
done
