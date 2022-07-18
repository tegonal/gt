#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.2.0-SNAPSHOT
#
#######  Description  #############
#
#  internal utility functions
#  no backward compatibility guarantees or whatsoever
#
###################################
set -eu

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"

function deleteDirChmod777() {
	local -r dir=$1
	# e.g files in .git will be write-protected and we don't want sudo for this command
	chmod -R 777 "$dir"
	rm -r "$dir"
}

function errorNoGpgKeysImported() {
	local -r remote=$1
	local -r publicKeysDir=$2
	local -r gpgDir=$3
	local -r unsecurePattern=$4

	logError "no GPG keys imported, you won't be able to pull files from the remote \033[0;36m%s\033[0m without using %s true\n" "$remote" "$unsecurePattern"
	printf >&2 "Alternatively, you can place public keys in %s or setup a gpg store yourself at %s\n" "$publicKeysDir" "$gpgDir"
	deleteDirChmod777 "$gpgDir"
	return 1
}

function findAscInDir() {
	local -r dir=$1
	shift
	find "$dir" -maxdepth 1 -type f -name "*.asc" "$@"
}

function noAscInDir() {
	local -r dir=$1
	shift 1
	(($(
		set -e
		findAscInDir "$dir" | wc -l
	) == 0))
}

function checkWorkingDirExists() {
	local workingDir=$1

	local scriptDir workingDirPattern
	scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	local -r scriptDir
	source "$scriptDir/shared-patterns.source.sh"

	if ! [[ -d $workingDir ]]; then
		logError "working directory \033[0;36m%s\033[0m does not exist\n" "$workingDir"
		echo >&2 "Check for typos and/or use $workingDirPattern to specify another"
		return 9
	fi
}

function invertBool() {
	local b=$1
	if [[ $b == true ]]; then
		echo "false"
	else
		echo "true"
	fi
}

function withOutput3Input4() {
	local fun=$1
	local tmpFile
	tmpFile=$(mktemp /tmp/gget.XXXXXXXXX)
	exec 3>"$tmpFile"
	exec 4<"$tmpFile"
	rm "$tmpFile"

	$fun

	exec 3>&-
	exec 4<&-
}
