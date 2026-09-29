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
# defines the parameters for afterVersionUpdateHook functions
#
###################################

# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced as well as traceAndDie
source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

local -ra afterVersionHookParams=(
	version "$versionParamPattern" "$versionParamDocu"
	projectsRootDir "$projectsRootDirParamPattern" "$projectsRootDirParamDocu"
	additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
)
