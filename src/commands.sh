#!/usr/bin/env bash

# examine 
EXAMINE_DESCRIPTION="System and device information"
EXAMINE_FLAGS=(
)

# new
NEW_DESCRIPTION="Create a new workflow or project based on the selected template"
NEW_FLAGS=(
)
# vllm
NEW_VLLM_DESCRIPTION="Creates a new project configured for vLLM"
NEW_VLLM_FLAGS=(
  "name,n,Project name,-,-"
  "framework,f,Framework to be used,-,-"
)
NEW_WORKFLOW_DESCRIPTION="Create a new accelerated workflow"
NEW_WORKFLOW_FLAGS=(
  "name,n,Workflow name,-,-"
)

# run
# nccl
# ...

# validate
VALIDATE_DESCRIPTION="Infrastructure functionality assessment"
VALIDATE_FLAGS=(
)
# nccl
VALIDATE_NCCL_DESCRIPTION="NVIDIA Collective Communications Library (NCCL) validation"
VALIDATE_NCCL_FLAGS=(
  "ngpus,g,Number of GPUs,1-8,1"
  "nthreads,t,Threads per process,1-64,1"
  "minbytes,b,Minimum message size,1B|4K|8M|1G,8M"
  "maxbytes,e,Maximum message size,1B|4K|1G|16G,1G"
  "iters,n,Timed iterations,1-1000,20"
  "datatype,d,Specify which datatype to use,int8|half|bfloat16|float,float"
  "stepfactor,f,Multiplication factor between sizes,2|4|8,2"
)