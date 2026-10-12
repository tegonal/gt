#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.13.0
#######  Description  #############
#
# Defines the parameters for the function releaseTemplate
#
###################################
{
	# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
	source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params-definition.source.sh" ||
		traceAndDie "could not source after-version-update-hook.params-definition.source.sh"
}
sourceOnce "$dir_of_tegonal_scripts/utility/array-utils.sh"

# version comes first, the remaining (currently optional) params come last.
local -a releaseTemplate_version=() releaseTemplate_rest=()
arrPartitionTuplesByKey afterVersionHookParams 3 releaseTemplate_version releaseTemplate_rest version

local -ra releaseTemplateParams=(
	"${releaseTemplate_version[@]}"
	releaseHook "$releaseHookParamPattern" "$releaseHookParamDocu"
	branch "$branchParamPattern" "$branchParamDocu"
	nextVersion "$nextVersionParamPattern" "$nextVersionParamDocu"
	prepareOnly "$prepareOnlyParamPattern" "$prepareOnlyParamDocu"
	beforePrFn "$beforePrFnParamPattern" "$beforePrFnParamDocu"
	prepareNextDevCycleFn "$prepareNextDevCycleFnParamPattern" "$prepareNextDevCycleFnParamDocu"
	afterVersionUpdateHook "$afterVersionUpdateHookParamPattern" "$afterVersionUpdateHookParamDocu"
	"${releaseTemplate_rest[@]}"
)
