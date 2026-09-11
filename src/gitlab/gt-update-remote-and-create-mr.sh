#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v2.0.2
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
if ! [[ -v dir_of_gt_gitlab ]]; then
	dir_of_gt_gitlab="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt_gitlab
fi
source "$dir_of_gt_gitlab/utils.sh"

function updateGtRemote() {
	local remoteName=$1
	shift 1 || die "could not shift by 1"

	# shellcheck disable=SC2034   # is passed by name to exitIfEnvVarNotSet
	local -a envVars=(
		GT_UPDATE_API_TOKEN
		CI_SERVER_HOST
	)
	exitIfEnvVarNotSet envVars
	# shellcheck disable=SC2034	# is used in credential.helper but indirectly
	readonly GT_UPDATE_API_TOKEN CI_SERVER_HOST

	function exchangeGitlabGitUrlsToHttp() {

		# We no longer use the ssh approach. Using an access token is encouraged by Gitlab by now.
		# However, the gt remotes might still be setup via ssh which is fine for local usage (by devs) but not if we
		# want to use the GT_UPDATE_API_TOKEN to fetch files in this CI job.
		# Now, since gt will setup git repos based on the gitconfig files in the remote and because
		# we don't want to modify those files (as we are going to commit the changes and we cannot now if they are
		# updated via gt update) we use url.insteadOf to rewrite and credential.helper.
		# Since we don't know what Gitlab-runner type is in use and if using git config --global could persist over runs
		# we make use of GIT_CONFIG_GLOBAL to define an own global and remove all changes in the end again

		# 1. create a tmp file which we use a GIT_CONFIG_GLOBAL
		local tmpGitConfigGlobal
		tmpGitConfigGlobal=$(mktemp -d -t gt-git-global-XXXXXXXXXX)
		export GIT_CONFIG_GLOBAL="$tmpGitConfigGlobal/.gitconfig"

		# shellcheck disable=SC2034   # is passed by name to cleanupTmp
		readonly -a tmpPaths=(tmpGitConfigGlobal)
		trap 'cleanupTmp tmpPaths' EXIT

		# 2. Seed with the HOME .gitconfig (in case the runner has set something up)
		if [[ -f "$HOME/.gitconfig" ]]; then
			cat "$HOME/.gitconfig" >>"$GIT_CONFIG_GLOBAL"
		fi

		# 3. Seed with the XDG global location, if present.
		#    Respects a custom XDG_CONFIG_HOME; falls back to ~/.config per spec.
		XDG_GIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
		if [[ -f "$XDG_GIT_CONFIG" ]]; then
			cat "$XDG_GIT_CONFIG" >>"$GIT_CONFIG_GLOBAL"
		fi

		# 3. Add our rewrites, switch from ssh to https so that we can use the GT_UPDATE_API_TOKEN
		git config --global "url.https://${CI_SERVER_HOST}/.insteadOf" "git@${CI_SERVER_HOST}:"
		git config --global "credential.https://${CI_SERVER_HOST}.helper" \
			"!f() { echo username=gt-bot; echo password=\$GT_UPDATE_API_TOKEN; }; f"
	}

	#gt-placeholder-gitlab-git-url-start
	exchangeGitlabGitUrlsToHttp
	#gt-placeholder-gitlab-git-url-end

	# placeholder in case you need to modify git also for other cases (e.g. for private GITHUB repos)
	#gt-placeholder-more-git-changes-start
	#gt-placeholder-more-git-changes-end

	echo "Updating remote: $remoteName"

	gt reset --gpg-only true -r "$remoteName"
	gt update -r "$remoteName"

	# placeholder in case you want to perform additional update steps which have to be after
	# gt update but before creating an MR -- if the steps can also be carried out before gt update, then we encourage
	# to define it via .gitlab-gt-update-remote-own-setup.yml
	#gt-placeholder-more-updates-start
	#gt-placeholder-more-updates-end

	local remoteVersion
	remoteVersion=$(git --git-dir=".gt/remotes/${remoteName}/repo/.git" tag | sort --version-sort | tail -n 1)

	#gt-placeholder-source-branch-start
	local -r sourceBranch="update/$remoteName"
	#gt-placeholder-source-branch-end

	#gt-placeholder-commit-title-start
	local -r commitTitle="update files of remote $remoteName to version $remoteVersion via gt"
	#gt-placeholder-commit-title-end

	#gt-placeholder-mr-description-start
	local -r mergeRequestDescription="following the changes after running gt update -r \"$remoteName\" and reset gpg keys"
	#gt-placeholder-mr-description-end

	"$dir_of_gt_gitlab/create-mr.sh" "$sourceBranch" "$commitTitle" "$mergeRequestDescription"
}

${__SOURCED__:+return}
updateGtRemote "$@"
