#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168,SC2154
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License 1.2
#         /___/                           Please report bugs and contribute back your improvements
#                                         Version: v0.17.0-SNAPSHOT
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
# note if you change this structure, then you need to adopt gt-pull.sh => pullArgsFile
local -r pullArgsFile="$remoteDir/pull.args"
local -r pullHookFile="$remoteDir/pull-hook.sh"
local -r gitconfig="$remoteDir/gitconfig"
