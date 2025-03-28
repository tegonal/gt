#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.4.0-SNAPSHOT
#######  Description  #############
#
#  constants intended to be sourced into a function
#
###################################

local -r remoteParamPatternLong='--remote'
local -r remoteParamPattern="-r|$remoteParamPatternLong"

local -r workingDirParamPatternLong='--working-directory'
local -r workingDirParamPattern="-w|$workingDirParamPatternLong"
local -r defaultWorkingDir='.gt'
local -r workingDirParamDocu="(optional) path which gt shall use as working directory -- default: $defaultWorkingDir"

local -r pullDirParamPatternLong='--directory'
local -r pullDirParamPattern="-d|$pullDirParamPatternLong"

local -r autoTrustParamPatternLong='--auto-trust'
local -r autoTrustParamPattern="$autoTrustParamPatternLong"
local -r autoTrustParamDocu="(optional) if set to true and GPG is not set up yet, then all keys in $defaultWorkingDir/remotes/<remote>/public-keys/*.asc are imported without manual consent -- default: false"

local -r tagParamPatternLong='--tag'
local -r tagParamPattern="-t|$tagParamPatternLong"

local -r tagFilterParamPatternLong='--tag-filter'
local -r tagFilterParamPattern="$tagFilterParamPatternLong"
local -r tagFilterParamDocu='(optional) define a regexp pattern (as supported by grep -E) to filter available tags when determining the latest tag'

local -r unsecureParamPatternLong='--unsecure'
local -r unsecureParamPattern="$unsecureParamPatternLong"

local -r pulledTsvLatestVersion="1.1.0"
local -r pulledTsvLatestVersionPragmaWithoutVersion='#@ Version: '
local -r pulledTsvLatestVersionPragma="${pulledTsvLatestVersionPragmaWithoutVersion}$pulledTsvLatestVersion"
local -r pulledTsvHeader=$'tag\tfile\trelativeTarget\ttagFilter\tsha512'

local -r pathParamPatternLong='--path'
local -r pathParamPattern="-p|$pathParamPatternLong"

local -r chopPathParamPatternLong='--chop-path'
local -r chopPathParamPattern="$chopPathParamPatternLong"

local -r signingKeyAsc='signing-key.public.asc'

local -r targetFileNamePatternLong='--target-file-name'
local -r targetFileNamePattern="$targetFileNamePatternLong"

local -r gpgOnlyParamPatternLong="--gpg-only"
local -r gpgOnlyParamPattern="$gpgOnlyParamPatternLong"

local -r listParamPatternLong="--list"
local -r listParamPattern="$listParamPatternLong"
