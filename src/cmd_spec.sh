#!/usr/bin/env bash

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# derive from SCRIPT_DIR
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"
WORKFLOWS_PATH="$SCRIPT_DIR/../submodules/workflows"

# constants
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths workflows)")"

# examine 
EXAMINE_DESCRIPTION="System and device information"
EXAMINE_FLAGS=(
)

# new
NEW_DESCRIPTION="Create a new workflow or project based on the selected template"
NEW_FLAGS=(
)
# workflow
NEW_WORKFLOW_DESCRIPTION="Create a new accelerated workflow"
NEW_WORKFLOW_FLAGS=(
  "name,n,Workflow name,-,-"
  "delete,d,Deletes an existing workflow,-,-"
)
NEW_WORKFLOW_FLAGS_MANDATORY="name"

# run
# nccl
# ...

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