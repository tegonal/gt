#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please remotert bugs and contribute back your improvements
#         /___/
#                                         Version: v1.2.0
#
#######  Description  #############
#
#  utility functions for dealing with git
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
#
#    declare currentBranch
#    currentBranch=$(currentGitBranch)
#    echo "current git branch is: $currentBranch"
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
#    echo "all existing tags on remote origin, starting from smallest to biggest version number"
#    remoteTagsSorted
#
#    # if you specify the name of the remote, then all additional arguments are passed to `sort` which is used internally
#    echo "all existing tags on remote upstream, starting from smallest to biggest version number"
#    remoteTagsSorted upstream -r
#
#    declare latestTag
#    latestTag=$(latestRemoteTag)
#    echo "latest tag on origin: $latestTag"
#    latestTag=$(latestRemoteTag upstream)
#    echo "latest tag on upstream: $latestTag"
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function currentGitBranch() {
	git rev-parse --abbrev-ref HEAD
}

function hasGitChanges() {
	local gitStatus
	gitStatus=$(git status --porcelain) || die "the following command failed (see above): git status --porcelain"
	[[ $gitStatus != "" ]]
}

function exitIfGitHasChanges() {
	# shellcheck disable=SC2310		# we are aware of that `if` will disable set -e for hasGitChanges
	if hasGitChanges; then
		logError "you have uncommitted changes, please commit/stash first, following the output of git status:"
		git status || exit $?
		exit 1
	fi
}

function countCommits() {
	local from to
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(from to)
	parseFnArgs params "$@"
	git rev-list --count "$from..$to" || die "could not count commits for $from..$to, see above"
}

function localGitIsAhead() {
	if ! (($# == 1)) && ! (($# == 2)); then
		traceAndDie "you need to pass at least the branch name to localGitIsAhead and optionally the name of the remote (defaults to origin) but not more, given: %s" "$#"
	fi
	local -r branch=$1
	local -r remote=${2:-"origin"}
	local -i count
	# shellcheck disable=SC2310		# we know that set -e is disabled for countCommits, that OK
	count=$(countCommits "$remote/$branch" "$branch") || die "the following command failed (see above): countCommits \"$remote/$branch\" \"$branch\""
	! ((count == 0))
}

function localGitIsBehind() {
	if ! (($# == 1)) && ! (($# == 2)); then
		traceAndDie "you need to pass at least the branch name to localGitIsBehind and optionally the name of the remote (defaults to origin) but not more, given: %s" "$#"
	fi
	local -r branch=$1
	local -r remote=${2:-"origin"}
	local -i count
	# shellcheck disable=SC2310			# we know that set -e is disabled for countCommits, that OK
	count=$(countCommits "$branch" "$remote/$branch") || die "the following command failed (see above): countCommits \"$branch\" \"$remote/$branch\""
	! ((count == 0))
}

function hasRemoteTag() {
	if ! (($# == 1)) && ! (($# == 2)); then
		traceAndDie "you need to pass at least the tag to hasRemoteTag and optionally the name of the remote (defaults to origin) but not more, given: %s" "$#"
	fi
	local -r tag=$1
	local -r remote=${2:-"origin"}
	shift 1 || die "could not shift by 1"
	local output
	output=$(git ls-remote -t "$remote") || die "the following command failed (see above): git ls-remote -t \"$remote\""
	grep "$tag" >/dev/null <<<"$output"
}

function remoteTagsSorted() {
	local remote="origin"
	if (($# > 0)); then
		remote=$1
		shift || die "could not shift by 1"
	fi
	git ls-remote --refs --tags "$remote" |
		cut --delimiter='/' --fields=3 |
		sort --version-sort "$@"
}

function latestRemoteTag() {
	if (($# > 1)); then
		traceAndDie "you can optionally pass the name of the remote (defaults to origin) to latestRemoteTag but not more, given: %s" "$#"
	fi
	local -r remote=${1:-"origin"}
	local tag
	#shellcheck disable=SC2310			# we are aware of that || will disable set -e for remoteTagsSorted
	tag=$(remoteTagsSorted "$remote" | tail -n 1) || die "could not get remote tags sorted, see above"
	if [[ -z $tag ]]; then
		die "looks like remote \033[0;36m%s\033[0m does not have a tag yet." "$remote"
	fi
	echo "$tag"
}
