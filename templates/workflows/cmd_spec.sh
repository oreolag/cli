#!/usr/bin/env bash

# helpers
lower() {
  printf '%s' "${1,,}"
}

NEW_DESCRIPTION="New description"
NEW_FLAGS=(
  "name,n,Project name,-,-"
  "push,p,Push to GitHub,0|1,1"
)
NEW_FLAGS_MANDATORY="name,push"

BUILD_DESCRIPTION="Build description"
BUILD_FLAGS=(
  "name,n,Project name,-,-"
)
BUILD_FLAGS_MANDATORY="name"

DELETE_DESCRIPTION="Deletes a $(lower WFNAME) project"
DELETE_FLAGS=(
  "name,n,Project name,-,-"
)
DELETE_FLAGS_MANDATORY="name"

PROGRAM_DESCRIPTION="Program description"
PROGRAM_FLAGS=(
  "name,n,Project name,-,-"
)
PROGRAM_FLAGS_MANDATORY="name"

RUN_DESCRIPTION="Run description"
RUN_FLAGS=(
  "name,n,Project name,-,-"
)
RUN_FLAGS_MANDATORY="name"

VALIDATE_DESCRIPTION="Validate description"
VALIDATE_FLAGS=(
  "flag1,a,Flag 1 description,1-8,1"
  "flag2,b,Flag 2 description,8|16,8"
)
VALIDATE_FLAGS_MANDATORY="flag1,flag2"