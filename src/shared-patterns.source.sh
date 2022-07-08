#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168

local -r REMOTE_PATTERN='-r|--remote'
local -r WORKING_DIR_PATTERN='-w|--working-directory'
local -r PULL_DIR_PATTERN='-d|--directory'

# in case you should add alternatives, then you need to modify gget-remote.sh where we write to pull.args
local -r UNSECURE_PATTERN='--unsecure'

local -r DEFAULT_WORKING_DIR='.gget'
