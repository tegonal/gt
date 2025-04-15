#!/usr/bin/env bash
# shellcheck disable=SC2168,SC2154
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.0
#######  Description  #############
#
#  intended to be sourced into a function which expects params version and nextVersion
#  Expects a variable `versionRegex` to be defined, specifying the semver regex.
#
###################################

if [[ -v version ]]; then
	if ! [[ -v nextVersion ]] && [[ "$version" =~ $versionRegex ]]; then
		nextVersion="${BASH_REMATCH[1]}.$((BASH_REMATCH[2] + 1)).0"
	else
		logInfo "cannot deduce nextVersion from version as it does not follow format vX.Y.Z(-RC...): $version"
	fi
fi
