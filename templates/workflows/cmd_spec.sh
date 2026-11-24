#!/usr/bin/env bash

# constants
INVENTORY_PATH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths inventory)"

# helpers
lower() {
  printf '%s' "${1,,}"
}

CREATE_WFNAME_DESCRIPTION="Create description"
CREATE_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
  "push,p,Push to GitHub,0|1,1"
)
CREATE_WFNAME_FLAGS_MANDATORY="name,push"

BUILD_WFNAME_DESCRIPTION="Build description"
BUILD_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
)
BUILD_WFNAME_FLAGS_MANDATORY="name"

DELETE_WFNAME_DESCRIPTION="Deletes a $(lower WFNAME) project"
DELETE_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
)
DELETE_WFNAME_FLAGS_MANDATORY="name"

PROGRAM_WFNAME_DESCRIPTION="Program device description"
PROGRAM_WFNAME_FLAGS=(
  "devices,d,Comma-separated list of device indices,-,-"
  "name,n,Project name,-,-"
  "hosts,,Target host or group from ${bold:-}$INVENTORY_PATH/hosts_$USER${normal:-} (default: local),-,local"
)
PROGRAM_WFNAME_FLAGS_MANDATORY="devices,name"

RUN_WFNAME_DESCRIPTION="Run description"
RUN_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
)
RUN_WFNAME_FLAGS_MANDATORY="name"

VALIDATE_WFNAME_DESCRIPTION="Validate description"
VALIDATE_WFNAME_FLAGS=(
  "devices,d,Comma-separated list of device indices,-,-"
  "flag1,a,Flag 1 description,1-8,1"
  "flag2,b,Flag 2 description,8|16,8"
)
VALIDATE_WFNAME_FLAGS_MANDATORY="devices,flag1,flag2"
