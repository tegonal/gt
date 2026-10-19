#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.2.0
#######  Description  #############
#
# Defines default args for ...params-definition.source.sh for files which use the same arguments but allow optional
# parameters (the afterVersionUpdateHook as such should not)
#
###################################

if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath ".") || die "could not determine realpath of ."; fi
# shellcheck disable=SC2154	# defined in common-constants which we assume is sourced when this file is sourced
if ! [[ -v additionalPattern ]]; then additionalPattern="$additionalPatternDefaultArg"; fi
