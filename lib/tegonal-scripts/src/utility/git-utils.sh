#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v4.8.1
#
#######  Description  #############
#
#  utility functions for dealing with git
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
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
#    latestTag=$(latestRemoteTag origin "^v1\.[0-9]+\.[0-9]+$")
#    echo "latest tag in the major 1.x.x series on origin without release candidates: $latestTag"
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/string-utils.sh"

function currentGitBranch() {
	git rev-parse --abbrev-ref HEAD
}

function hasGitChanges() {
	local gitStatus
	gitStatus=$(git status --porcelain) || die "the following command failed (see above): git status --porcelain"
	[[ $gitStatus != "" ]]
}

function exitIfGitHasChanges() {
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
	parseFnArgs params "$@" || return $?
	git rev-list --count "$from..$to" || die "could not count commits for $from..$to, see above"
}

function localGitIsAhead() {
	if (($# != 1)) && (($# != 2)); then
		traceAndDie "you need to pass at least the branch name to localGitIsAhead and optionally the name of the remote (defaults to origin) but not more, given: %s" "$#"
	fi
	local -r branch=$1
	local -r remote=${2:-"origin"}
	local -i count
	count=$(countCommits "$remote/$branch" "$branch") || die "the following command failed (see above): countCommits \"$remote/$branch\" \"$branch\""
	! ((count == 0))
}

function localGitIsBehind() {
	if (($# != 1)) && (($# != 2)); then
		traceAndDie "you need to pass at least the branch name to localGitIsBehind and optionally the name of the remote (defaults to origin) but not more, given: %s" "$#"
	fi
	local -r branch=$1
	local -r remote=${2:-"origin"}
	local -i count
	count=$(countCommits "$branch" "$remote/$branch") || die "the following command failed (see above): countCommits \"$branch\" \"$remote/$branch\""
	! ((count == 0))
}

function hasRemoteTag() {
	if (($# != 1)) && (($# != 2)); then
		traceAndDie "you need to pass at least the tag to hasRemoteTag and optionally the name of the remote (defaults to origin) but not more, given: %s" "$#"
	fi
	local -r tag=$1
	local -r remote=${2:-"origin"}
	shift 1 || traceAndDie "could not shift by 1"
	local output literalTag
	output=$(git ls-remote -t "$remote") || die "the following command failed (see above): git ls-remote -t \"$remote\""
	literalTag=$(escapeRegex "refs/tags/$tag") || die "was not able to escape the following for regex: %s" "refs/tags/$tag"
	grep -q -E "$literalTag\$" <<<"$output"
}

function remoteTagsSorted() {
	local remote="origin"
	if (($# > 0)); then
		remote=$1
		shift 1 || traceAndDie "could not shift by 1"
	fi
	git ls-remote --refs --tags "$remote" |
		cut --delimiter='/' --fields=3 |
		sort --version-sort "$@"
}

function latestRemoteTag() {
	if (($# > 2)); then
		logError "Maximum 2 arguments can be passed to latestRemoteTag, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: remote   	(optional) the name of the remote, defaults to origin'
		echo >&2 '2: tagFilter	(optional) a regex pattern (as supported by grep -E) which allows to filter available tags before determining the latest, defaults to .* (i.e. include all)'
		printStackTrace
		exit 9
	fi
	local -r remote=${1:-"origin"}
	local -r tagFilter=${2:-".*"}
	local tag
	tag=$(remoteTagsSorted "$remote" | grep -E "$tagFilter" | tail -n 1) || die "could not get remote tags sorted for remote %s, see above" "$remote"
	if [[ -z $tag ]]; then
		die "looks like remote \033[0;36m%s\033[0m does not have a tag yet." "$remote"
	fi
	echo "$tag"
}
