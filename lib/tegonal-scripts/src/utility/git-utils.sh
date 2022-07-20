#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.10.0
#
#######  Description  #############
#
#  utility functions for dealing with git
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
#
#    echo "current git branch is: $(currentGitBranch)"
#
#    if hasGitChanges; then
#    	echo "do whatever you want to do..."
#    fi
#
#    if localGitIsAhead "main"; then
#    	echo "do whatever you want to do..."
#    elif localGitIsAhead "main" "anotherRemote"; then
#    	echo "do whatever you want to do..."
#    fi
#
#    if localGitIsBehind "main"; then
#    	echo "do whatever you want to do..."
#    elif localGitIsBehind "main"; then
#    	echo "do whatever you want to do..."
#    fi
#
#    if hasRemoteTag "v0.1.0"; then
#    	echo "do whatever you want to do..."
#    elif hasRemoteTag "v0.1.0" "anotherRemote"; then
#    	echo "do whatever you want to do..."
#    fi
#
###################################
set -euo pipefail

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"

function currentGitBranch() {
	git rev-parse --abbrev-ref HEAD
}

function hasGitChanges() {
	local -r gitStatus=$(git status --porcelain)
	! [[ $gitStatus == "" ]]
}

function localGitIsAhead() {
	if ! (($# == 0)) && ! (($# == 1)); then
		die "you need to pass at least the branch name to localGitIsAhead and optionally the name of the remote (defaults to origin)"
	fi
	local -r branch=$1
	local -r remote=${2-"origin"}
	! (($(git rev-list --count "$remote/${branch}..$branch") == 0))
}

function localGitIsBehind() {
	if ! (($# == 0)) && ! (($# == 1)); then
		die "you need to pass at least the branch name to localGitIsBehind and optionally the name of the remote (defaults to origin)"
	fi
	local -r branch=$1
	local -r remote=${2-"origin"}
	! (($(git rev-list --count "${branch}..$remote/$branch") == 0))
}

function hasRemoteTag() {
	if ! (($# == 0)) && ! (($# == 1)); then
		die "you need to pass at least the tag to hasRemoteTag and optionally the name of the remote (defaults to origin)"
	fi
	local -r tag=$1
	local -r remote=${2-"origin"}
	git ls-remote -t "$remote" | grep "$tag" >/dev/null || false
}
