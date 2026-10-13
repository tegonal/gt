#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.1.0
#######  Description  #############
#
# Defines the parameters for the a custom release function which is based on releaseFilesTemplate but wants to
# hide certain params from the consumers (see below)
#
###################################
{
	# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
	source "$dir_of_tegonal_scripts/releasing/params/release-files-template.params-definition.source.sh" ||
		traceAndDie "could not source release-files-template.params-definition.source.sh"
}

local -a releaseFiles_sameAsFilesWithSomeExceptions=()
arrDropTuplesByKey releaseFilesTemplateParams 3 releaseFiles_sameAsFilesWithSomeExceptions \
	findForSigning prepareNextDevCycleFn afterVersionUpdateHook projectsRootDir additionalPattern

local -ra releaseFilesParams=(
	"${releaseFiles_sameAsFilesWithSomeExceptions[@]}"
)
