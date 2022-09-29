#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.8.0-SNAPSHOT
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GGET_VERSION='v0.8.0-SNAPSHOT'

function exitIfEnvVarNotSet() {
	local -rn exitIfEnvVarNotSet_arr=$1
	shift 1

	declare error=false
	for envName in "${exitIfEnvVarNotSet_arr[@]}"; do
		if ! [[ -v "$envName" ]] || [[ -z ${!envName} ]]; then
			echo "Looks like you forgot to define the variable $envName"
			error=true
		fi
	done
	if [[ $error == true ]]; then
		echo "In GitLab, go to Settings => CI/CD => Variables and define it/them there"
		echo "See also https://github.com/tegonal/gget/tree/${GGET_VERSION}#gitlab-job for further information"
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
