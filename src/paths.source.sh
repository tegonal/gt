#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168,SC2154
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.9.0
#
#######  Description  #############
#
#  constants intended to be sourced into a function.
#	 Requires that $workingDirAbsolute is defined beforehand
#
###################################

local -r remotesDir="$workingDirAbsolute/remotes"
local -r remoteDir="$remotesDir/$remote"
local -r publicKeysDir="$remoteDir/public-keys"
local -r repo="$remoteDir/repo"
local -r gpgDir="$publicKeysDir/gpg"
local -r pulledTsv="$remoteDir/pulled.tsv"
# note if you change this structure, then you need to adopt gget-pull.sh => pullArgsFile
local -r pullArgsFile="$remoteDir/pull.args"
local -r pullHookFile="$remoteDir/pull-hook.sh"
local -r gitconfig="$remoteDir/gitconfig"
