#!/bin/bash

CMDB_PATH=$1
server_type=$2

# get devices from CMDB
accel=$($CMDB_PATH/cmdb_get.py cpu numa 0 accel)
gpu=$($CMDB_PATH/cmdb_get.py cpu numa 0 gpu)

# print
if [ "$server_type" = "accel" ]; then
    if [ "$accel" = "" ]; then
        echo "0"
    else
        echo "1"
    fi
elif [ "$server_type" = "gpu" ]; then
    if [ "$gpu" = "" ]; then
        echo "0"
    else
        echo "1"
    fi
elif [ "$server_type" = "build" ]; then
    # a build server does not have accel or gpu
    if [ "$accel" = "" ] && [ "$gpu" = "" ]; then
        echo "1"
    else
        echo "0"
    fi
fi