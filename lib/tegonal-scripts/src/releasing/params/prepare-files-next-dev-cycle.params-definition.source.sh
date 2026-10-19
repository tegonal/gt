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
# Defines the parameters for a prepareNextDevCycle function which is based on prepareNextDevCycleTemplate
# but defines an own pattern for additionalPattern
#
###################################
{
	# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
	source "$dir_of_tegonal_scripts/releasing/params/prepare-files-next-dev-cycle-template.params-definition.source.sh" ||
		traceAndDie "could not source prepare-files-next-dev-cycle-template.params-definition.source.sh"
}

local -a prepareFilesNextDevCycle_withoutAdditionalPattern=()
arrDropTuplesByKey prepareFilesNextDevCycleTemplateParams 3 prepareFilesNextDevCycle_withoutAdditionalPattern additionalPattern

local -ra prepareFilesNextDevCycleParams=(
	"${prepareFilesNextDevCycle_withoutAdditionalPattern[@]}"
	additionalPattern "$additionalPatternParamPattern" "is ignored because the function itself overwrites it, still here as release-files-template uses this argument"
)
