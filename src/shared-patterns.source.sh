#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.10.0-SNAPSHOT
#
#######  Description  #############
#
#  constants intended to be sourced into a function
#
###################################

local -r remotePattern='-r|--remote'
local -r workingDirPattern='-w|--working-directory'
local -r pullDirPattern='-d|--directory'
local -r autoTrustPattern='--auto-trust'
local -r tagPattern='-t|--tag'

# in case you should add alternatives, then you need to modify error messages and the like, search for unsecurePattern
local -r unsecurePattern='--unsecure'

local -r defaultWorkingDir='.gget'
local -r workingDirParamDocu="(optional) path which gget shall use as working directory -- default: $defaultWorkingDir"
local -r autoTrustParamDocu="(optional) if set to true, all public-keys stored in $defaultWorkingDir/remotes/<remote>/public-keys/*.asc are imported if GPG verification fails and in such a case without the need of a manual consent -- default: false"
