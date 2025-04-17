#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.5.0-SNAPSHOT
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export GT_VERSION='v1.5.0-SNAPSHOT'

function exitIfEnvVarNotSet() {
	local -rn exitIfEnvVarNotSet_arr=$1
	shift 1 || exit 1

	declare error=false
	for envName in "${exitIfEnvVarNotSet_arr[@]}"; do
		if ! [[ -v "$envName" ]] || [[ -z ${!envName} ]]; then
			echo >&2 "Looks like you forgot to define the variable $envName"
			error=true
		fi
	done
	if [[ $error == true ]]; then
		echo >&2 "In GitLab, go to Settings => CI/CD => Variables and define it/them there"
		echo >&2 "See also https://github.com/tegonal/gt/tree/${GT_VERSION}#gitlab-job for further information"
		exit 1
	fi
}

function cleanupTmp() {
	local -rn cleanupTmp_paths=$1
	for path in "${cleanupTmp_paths[@]}"; do
		if [[ -v "$path" && -n ${!path} ]]; then
			rm -rf "$path"
		fi
	done
}
