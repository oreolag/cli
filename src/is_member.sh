#!/bin/bash

username=$1
groupname=$2

if getent group $groupname | grep -q "\b${username}\b"; then
    echo "1"
else
    echo "0"
fi