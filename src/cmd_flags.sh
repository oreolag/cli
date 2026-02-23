#!/usr/bin/env bash

# examine 
EXAMINE_DESCRIPTION="System and device information"
EXAMINE_FLAGS=(
)

# run
# nccl
# ...

# validate
# nccl
VALIDATE_NCCL_DESCRIPTION="Validate NCCL"
VALIDATE_NCCL_FLAGS=(
  "ngpus,g,Number of GPUs,1-8,1"
  "nthreads,t,Threads per process,1-64,1"
  "minbytes,b,Minimum message size,1B|4K|8M|1G,8M"
  "maxbytes,e,Maximum message size,1B|4K|1G|16G,1G"
  "iters,n,Timed iterations,1-1000,20"
  "datatype,d,Specify which datatype to use,int8|half|bfloat16|float,float"
  "stepfactor,f,Multiplication factor between sizes,2|4|8,2"
)