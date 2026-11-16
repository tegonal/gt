#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.3.0
#######  Description  #############
#
# Defines default args for ...params-definition.source.sh
#
###################################
{
	# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
	source "$dir_of_tegonal_scripts/releasing/params/release-template.default-args.source.sh" ||
		traceAndDie "could not source release-template.default-args.source.sh"
}
# currently release defines not more optional params than release-template, on the contrary, since we don't
# want to expose all params to the user, we have to unset certain values which are set
# shellcheck disable=SC2154		# we assume default-args is sourced after params-definition
for var in "${release_hideFromUser[@]}"; do
	unset "$var"
done
