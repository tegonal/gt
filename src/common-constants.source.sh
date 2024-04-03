#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.18.0-SNAPSHOT
#######  Description  #############
#
#  constants intended to be sourced into a function
#
###################################

local -r remoteParamPattern='-r|--remote'

local -r workingDirParamPattern='-w|--working-directory'
local -r defaultWorkingDir='.gt'
local -r workingDirParamDocu="(optional) path which gt shall use as working directory -- default: $defaultWorkingDir"

local -r pullDirParamPattern='-d|--directory'

local -r autoTrustParamPattern='--auto-trust'
local -r autoTrustParamDocu="(optional) if set to true, all public-keys stored in $defaultWorkingDir/remotes/<remote>/public-keys/*.asc are imported if GPG verification fails and in such a case without the need of a manual consent -- default: false"

local -r tagParamPattern='-t|--tag'

# in case you should add alternatives, then you need to modify error messages and the like, search for unsecureParamPattern
local -r unsecureParamPattern='--unsecure'

local -r pulledTsvLatestVersion="1.0.0"
local -r pulledTsvLatestVersionPragma="#@ Version: $pulledTsvLatestVersion"
local -r pulledTsvHeader=$'tag\tfile\trelativeTarget\tsha512'
