#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.13.0-SNAPSHOT
#######  Description  #############
#
# defines local variables for the params defined in ...params-definition.source.sh
#
###################################

# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
source "$dir_of_tegonal_scripts/releasing/after-version-update-hook.params.source.sh" || traceAndDie "could not source after-version-update-hook.params.source.sh"

local branch releaseHook nextVersion prepareOnly beforePrFn prepareNextDevCycleFn afterVersionUpdateHook
