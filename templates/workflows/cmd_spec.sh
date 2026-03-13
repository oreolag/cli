#!/usr/bin/env bash

NEW_WFNAME_DESCRIPTION="New description"
NEW_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
)
NEW_WFNAME_FLAGS_MANDATORY="name"

BUILD_WFNAME_DESCRIPTION="Build description"
BUILD_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
  "flag1,a,Flag 1 description,1-8,1"
  "flag2,b,Flag 2 description,-,-"
)
BUILD_WFNAME_FLAGS_MANDATORY="name,flag1"

PROGRAM_WFNAME_DESCRIPTION="Program description"
PROGRAM_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
  "flag1,a,Flag 1 description,1-8,1"
  "flag2,b,Flag 2 description,-,-"
)
PROGRAM_WFNAME_FLAGS_MANDATORY="name,flag1"

RUN_WFNAME_DESCRIPTION="Run description"
RUN_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
  "flag1,a,Flag 1 description,1-8,1"
  "flag2,b,Flag 2 description,-,-"
)
RUN_WFNAME_FLAGS_MANDATORY="name,flag1"

VALIDATE_WFNAME_DESCRIPTION="Validate description"
VALIDATE_WFNAME_FLAGS=(
  "name,n,Project name,-,-"
  "flag1,a,Flag 1 description,1-8,1"
  "flag2,b,Flag 2 description,-,-"
)
VALIDATE_WFNAME_FLAGS_MANDATORY="name,flag1"