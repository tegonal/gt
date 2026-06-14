#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168,SC2154
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.7.0-SNAPSHOT
#######  Description  #############
#
#  defines constants pointing to source root directories intended to be sourced in sh files
#
###################################

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	readonly projectDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$scriptsDir/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi

if ! [[ -v dir_of_github_commons ]]; then
	dir_of_github_commons="$scriptsDir/../lib/tegonal-gh-commons/src"
	readonly dir_of_github_commons
fi
