#!/usr/bin/env bash

NEW_WFNAME_DESCRIPTION="New description"
NEW_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
  "push,p,Push to GitHub,0|1,1"
)
NEW_WFNAME_FLAGS_MANDATORY="name,push"

BUILD_WFNAME_DESCRIPTION="Build description"
BUILD_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
)
BUILD_WFNAME_FLAGS_MANDATORY="name"

PROGRAM_WFNAME_DESCRIPTION="Program description"
PROGRAM_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
)
PROGRAM_WFNAME_FLAGS_MANDATORY="name"

RUN_WFNAME_DESCRIPTION="Run description"
RUN_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
)
RUN_WFNAME_FLAGS_MANDATORY="name"

VALIDATE_WFNAME_DESCRIPTION="Validate description"
VALIDATE_WFNAME_FLAGS=(
  "flag1,a,Flag 1 description,1-8,1"
  "flag2,b,Flag 2 description,8|16,8"
)
VALIDATE_WFNAME_FLAGS_MANDATORY="flag1,flag2"