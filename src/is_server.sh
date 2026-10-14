#!/bin/bash

ODEV_PATH=$1
server_type=$2

# Booking roles come from the shared inventory, independently of hardware.
if [ "$server_type" = "booking" ]; then
    booking_db=${BOOKING_DB_FILE:-}
    if [ -z "$booking_db" ]; then
        booking_db=$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths booking) || exit $?
    fi
    # Older installations do not yet have paths.booking in vars.yml.
    booking_db=${booking_db:-/opt/booking.yml}
    python3 "$ODEV_PATH/src/booking_is_server.py" --db "$booking_db"
    exit $?
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
