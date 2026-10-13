#!/bin/bash

ODEV_PATH=$1
server_type=$2

# Booking is an explicit role, independent of the installed hardware.
if [ "$server_type" = "booking" ]; then
    booking_server=$("$ODEV_PATH/src/cmdb_get.py" booking is_server) || exit $?
    case "$booking_server" in
        True|true|1) echo "1" ;;
        False|false|0|"") echo "0" ;;
        *)
            echo "ERROR: booking.is_server must be true or false (or 1 or 0)" >&2
            exit 1
            ;;
    esac
    exit 0
fi

# get devices from CMDB
accel=$($ODEV_PATH/src/cmdb_get.py cpu numa 0 accel)
gpu=$($ODEV_PATH/src/cmdb_get.py cpu numa 0 gpu)

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
