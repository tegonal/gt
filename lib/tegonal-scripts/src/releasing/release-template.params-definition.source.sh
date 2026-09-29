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
# defines the parameters for xyz.sh in xyz.params-definitions.sh
#
###################################

# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
source "$dir_of_tegonal_scripts/releasing/after-version-update-hook.params-definition.source.sh" || traceAndDie "could not source after-version-update-hook.params-definition.source.sh"

local -ra releaseTemplateParams=(
	"${afterVersionHookParams[@]:0:3}"
	releaseHook "$releaseHookParamPattern" "$releaseHookParamDocu"
	branch "$branchParamPattern" "$branchParamDocu"
	nextVersion "$nextVersionParamPattern" "$nextVersionParamDocu"
	prepareOnly "$prepareOnlyParamPattern" "$prepareOnlyParamDocu"
	beforePrFn "$beforePrFnParamPattern" "$beforePrFnParamDocu"
	prepareNextDevCycleFn "$prepareNextDevCycleFnParamPattern" "$prepareNextDevCycleFnParamDocu"
	afterVersionUpdateHook "$afterVersionUpdateHookParamPattern" "$afterVersionUpdateHookParamDocu"
	# version comes first but we still want the remaining optional params
	"${afterVersionHookParams[@]:3}"
)
