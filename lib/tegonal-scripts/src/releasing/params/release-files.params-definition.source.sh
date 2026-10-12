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
# Defines the parameters for the function releaseFiles
#
###################################
{
	# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
	source "$dir_of_tegonal_scripts/releasing/params/release-template.params-definition.source.sh" ||
		traceAndDie "could not source release-template.params-definition.source.sh"
}

local -a releaseFiles_version=() releaseFiles_restWithoutReleaseHook=()
arrKeepTuplesByKey releaseTemplateParams 3 releaseFiles_version version
arrDropTuplesByKey releaseTemplateParams 3 releaseFiles_restWithoutReleaseHook version releaseHook

local -ra releaseFilesParams=(
	"${releaseFiles_version[@]}"
	key "$keyParamPattern" "$keyParamDocu"
	findForSigning "$findForSigningParamPattern" "$findForSigningParamDocu"
	"${releaseFiles_restWithoutReleaseHook[@]}"
)
