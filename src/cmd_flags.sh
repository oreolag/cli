#!/usr/bin/env bash

VALIDATE_NCCL_DESCRIPTION="Validate NCCL"
VALIDATE_NCCL_FLAGS=(
  "ngpus,g,Number of GPUs,1-10,1"
  "nthreads,t,Number of Threads,1-1024,10"
  "minbytes,b,Minimum Bytes,1B-1G,8M"
  "maxbytes,e,Maximum Bytes,1B-16G,100M"
)
