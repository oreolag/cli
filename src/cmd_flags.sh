#!/usr/bin/env bash

# run
# nccl
# ...

# validate
# nccl
VALIDATE_NCCL_DESCRIPTION="Validate NCCL"
VALIDATE_NCCL_FLAGS=(
  "ngpus,g,Number of GPUs,1-8,1"
  "nthreads,t,Threads per process,1-64,1"
  "minbytes,b,Minimum message size,1B-1G,8M"
  "maxbytes,e,Maximum message size,1B-16G,1G"
  "iters,n,Timed iterations,1-1000,20"
  "datatype,d,Specify which datatype to use,int8|half|bfloat16|float,float"
)
VALIDATE_NCCL_FLAGS_MANDATORY=(
  "ngpus"
  "maxbytes"
)