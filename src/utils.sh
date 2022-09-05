#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.5.1
#
#######  Description  #############
#
#  internal utility functions
#  no backward compatibility guarantees or whatsoever
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gget/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function exitBecauseNoGpgKeysImported() {
	local remote publicKeysDir gpgDir unsecurePattern
	# shellcheck disable=SC2034
	local -ra params=(remote publicKeysDir gpgDir unsecurePattern)
	parseFnArgs params "$@"

	logError "no GPG keys imported, you won't be able to pull files from the remote \033[0;36m%s\033[0m without using %s true\n" "$remote" "$unsecurePattern"
	printf >&2 "Alternatively, you can:\n- place public keys in %s or\n- setup a gpg store yourself at %s\n" "$publicKeysDir" "$gpgDir"
	deleteDirChmod777 "$gpgDir"
	exit 1
}

function findAscInDir() {
	local -r dir=$1
	shift
	find "$dir" -maxdepth 1 -type f -name "*.asc" "$@"
}

function noAscInDir() {
	local -r dir=$1
	shift 1
	local numberOfAsc
	# we are aware of that set -e is disabled for findAscInDir
	#shellcheck disable=SC2310
	numberOfAsc=$(findAscInDir "$dir" | wc -l) || die "could not find the number of *.asc files in dir %s, see errors above" "$dir"
	((numberOfAsc == 0))
}

function checkWorkingDirExists() {
	local workingDirAbsolute=$1
	shift

	local workingDirPattern
	source "$dir_of_gget/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	if ! [[ -d $workingDirAbsolute ]]; then
		logError "working directory \033[0;36m%s\033[0m does not exist" "$workingDirAbsolute"
		echo >&2 "Check for typos and/or use $workingDirPattern to specify another"
		return 9
	fi
}

function exitIfWorkingDirDoesNotExist() {
	# we are aware of that || will disable set -e for checkWorkingDirExists
	# shellcheck disable=SC2310
	checkWorkingDirExists "$@" || exit $?
}

function exitIfRemoteDirDoesNotExist() {
	local -r workingDirAbsolute=$1
	local -r remote=$2
	shift 2
	local remoteDir
	source "$dir_of_gget/paths.source.sh" || die "could not source paths.source.sh"

	if ! [[ -d $remoteDir ]]; then
		logError "remote \033[0;36m%s\033[0m does not exist, check for typos.\nFollowing the remotes which exist:" "$remote"
		sourceOnce "$dir_of_gget/gget-remote.sh"
		gget_remote_list -w "$workingDirAbsolute"
		exit 9
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

function gitDiffChars() {
	local hash1 hash2
	hash1=$(git hash-object -w --stdin <<<"$1") || die "cannot calculate hash for string: %" "$1"
	hash2=$(git hash-object -w --stdin <<<"$2") || die "cannot calculate hash for string: %" "$2"
	shift 2
	git --no-pager diff "$hash1" "$hash2" \
		--word-diff=color --word-diff-regex . --ws-error-highlight=all |
		grep -A 1 @@ | tail -n +2
}

function initialiseGitDir() {
	local -r workingDirAbsolute=$1
	local -r remote=$2
	shift 2

	local repo gitconfig
	source "$dir_of_gget/paths.source.sh" || die "could not source paths.source.sh"

	mkdir -p "$repo" || die "could not create the repo at %s" "$repo"
	git --git-dir="$repo/.git" init || die "could not git init the repo at %s" "$repo"
}

function reInitialiseGitDir() {
	initialiseGitDir "$@"
	cp "$gitconfig" "$repo/.git/config" || die "could not copy %s to %s" "$gitconfig" "$repo/.git/config"
}

function initialiseGpgDir() {
	local -r gpgDir=$1
	shift
	mkdir "$gpgDir" || die "could not create the gpg directory at %s" "$gpgDir"
	# it's OK if we are not able to set the rights as we only use it temporary. This will cause warnings by gpg
	# so the user could be aware of that something went wrong
	chmod 700 "$gpgDir" || true
}

function latestRemoteTagIncludingChecks() {
	if ! (($# == 2)); then
		logError "you need to pass two arguments to latestRemoteTagIncludingChecks, given %s" "$#"
		echo "1: workingDirAbsolute"
		echo "2: remote"
		printStackTrace
		exit 9
	fi
	local -r workingDirAbsolute=$1
	local -r remote=$2

	local repo
	source "$dir_of_gget/paths.source.sh" || die "could not source paths.source.sh"

	local currentDir
	currentDir=$(pwd)

	local tagPattern
	source "$dir_of_gget/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	logInfo >&2 "no tag provided via argument %s, will determine latest and use it instead" "$tagPattern"
	cd "$repo" || die "could not cd to the repo to determine the latest tag: %s" "$repo"
	#		git fetch "$remote" 'refs/tags/*:refs/tags/*' || die "could not fetch the tags of remote %s and thus cannot determine latest tag"
	latestRemoteTag "$remote" || die "could not determine latest tag of remote \033[0;36m%s\033[0m and none set via argument %s" "$remote" "$tagPattern"
	if [[ -z $tag ]]; then
		die "looks like remote \033[0;36m%s\033[0m does not have a tag yet, cannot pull files from it." "$remote"
	fi
	cd "$currentDir"
	logInfo >&2 "latest is \033[0;36m%s\033[0m" "$tag"
}
