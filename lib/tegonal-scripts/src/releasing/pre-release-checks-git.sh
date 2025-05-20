#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.1
#######  Description  #############
#
# Checks that releasing a certain version (creating a corresponding git tag) makes sense: We check:
#  - the version follows the format vX.Y.Z(-RC...)
#  - there are no uncommitted changes
#  - checks current branch is `main` (we assume the convention that main is your default branch)
#  - the desired version does not exist as tag locally or on remote
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
#    # checks releasing v0.1.0 makes sense and the current branch is main
#    "$dir_of_tegonal_scripts/releasing/pre-release-checks-git.sh" -v v0.1.0
#
#    # checks releasing v0.1.0 makes sense and the current branch is hotfix-1.0
#    "$dir_of_tegonal_scripts/releasing/pre-release-checks-git.sh" -v v0.1.0 -b hotfix-1.0
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.8.1'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function preReleaseCheckGit() {
	local versionParamPatternLong
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local version branch
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" "$versionParamDocu"
		branch "$branchParamPattern" "$branchParamDocu"
	)

	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	if ! [[ -v branch ]]; then branch="main"; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"
	exitIfArgIsNotVersion "$version" "$versionParamPatternLong"

	exitIfGitHasChanges

	local tags
	tags=$(git tag) || die "The following command failed (see above): git tag"
	if grep -q --fixed-strings "$version" <<< "$tags"; then
		logError "tag %s already exists locally, adjust version or delete it with git tag -d %s" "$version" "$version"
		if hasRemoteTag "$version"; then
			printf >&2 "Note, it also exists on the remote which means you also need to delete it there -- e.g. via git push origin :%s\n" "$version"
			exit 1
		fi
		logInfo "looks like the tag only exists locally."
		if askYesOrNo "Shall I \`git tag -d %s\` and continue with the release?" "$version"; then
			git tag -d "$version" || die "deleting tag %s failed" "$version"
		else
			exit 1
		fi
	fi

	if hasRemoteTag "$version"; then
		logError "tag %s already exists on remote origin, adjust version or delete it with git push origin :%s\n" "$version" "$version"
		exit 1
	fi

	local currentBranch
	currentBranch="$(currentGitBranch)" || die "could not determine current git branch, see above"
	local -r currentBranch
	if [[ $currentBranch != "$branch" ]]; then
		logError "you need to be on the \033[0;36m%s\033[0m branch to release, check that you have merged all changes from your current branch \033[0;36m%s\033[0m." "$branch" "$currentBranch"
		if askYesOrNo "Shall I switch to %s for you?" "$branch"; then
			git checkout "$branch" || die "checking out branch \033[0;36m%s\033[0m failed" "$branch"
		else
			return 1
		fi
	fi

	git fetch || die "could not fetch latest changes from origin, cannot verify if we are up-to-date with remote or not"

	if localGitIsAhead "$branch"; then
		logError "you are ahead of origin, please push first and check if CI succeeds before releasing. Following your additional changes:"
		git -P log "origin/${branch}..$branch"
		if askYesOrNo "Shall I git push for you?"; then
			git push
			logInfo "please check if your push passes CI and re-execute the release command afterwards"
		fi
		return 1
	fi

	while localGitIsBehind "$branch"; do
		git fetch || die "could not fetch latest changes from origin, cannot verify if we are up-to-date with remote or not"
		logError "you are behind of origin. I already fetched the changes for you, please check if you still want to release. Following the additional changes in origin/main:"
		git -P log "${branch}..origin/$branch"
		if askYesOrNo "Do you want to git pull?"; then
			git pull || die "could not pull the changes, have to abort the release, please fix yourself and re-launch the release command"
			if ! askYesOrNo "Do you want to release now?"; then
				return 1
			fi
		else
			return 1
		fi
	done
}

${__SOURCED__:+return}
preReleaseCheckGit "$@"
