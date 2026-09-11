#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v2.0.3
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_gt_gitlab ]]; then
	dir_of_gt_gitlab="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt_gitlab
fi
source "$dir_of_gt_gitlab/utils.sh"

function commitAndCreateMrOnChanges() {
	local -r sourceBranch=$1
	local -r commitMessage=$2
	local -r mrDescription=$3
	shift 3 || die "could not shift by 3"

	# shellcheck disable=SC2034   # is passed by name to exitIfEnvVarNotSet
	local -a envVars=(
		GT_UPDATE_API_TOKEN
		CI_API_V4_URL
		CI_PROJECT_ID
		CI_SERVER_HOST
		CI_PROJECT_PATH
		CI_DEFAULT_BRANCH
	)
	exitIfEnvVarNotSet envVars
	readonly GT_UPDATE_API_TOKEN CI_API_V4_URL CI_PROJECT_ID CI_SERVER_HOST CI_PROJECT_PATH CI_DEFAULT_BRANCH

	local gitStatus
	gitStatus=$(git status --porcelain) || die "the following command failed (see above): git status --porcelain"

	if [[ $gitStatus == "" ]]; then
		logInfo "No git changes, no need to create a merge request"
		return 0
	fi

	logInfo "Detected changes, going to push changes to branch %s" "$sourceBranch"

	#gt-placeholder-user-email-start
	local -r userEmail="gt-bot@tegonal.com"
	#gt-placeholder-user-email-end

	git config user.email "$userEmail"
	git config user.name "tegonal-bot"
	git remote add gitlab_origin "https://gt-bot:$GT_UPDATE_API_TOKEN@$CI_SERVER_HOST/$CI_PROJECT_PATH.git"
	git branch -D "$sourceBranch" 2 &>/dev/null || true
	git checkout -b "$sourceBranch" || die "could not checkout branch %s" "$sourceBranch"
	git add . || die "could not add changes"
	git commit -m "$commitMessage" || die "could not commit"

	if [[ -f "./scripts/cleanup-on-push-to-main.sh" ]]; then
		if ./scripts/cleanup-on-push-to-main.sh; then
			git commit -am "cleanup after commit" || logInfo "Nothing to commit after cleanup"
		else
			logInfo "Cleanup failed, resetting to state after gt update"
			git reset --hard
		fi
	fi

	git push -f --set-upstream gitlab_origin "$sourceBranch" ||
		die "could not force push %s to %s" "$sourceBranch" "https://gt-bot@$CI_SERVER_HOST/$CI_PROJECT_PATH"

	logInfo "Going to create a merge request for the changes"

	local curlOutputFile
	curlOutputFile=$(mktemp -t "curl-output-XXXXXXXXXX")

	# shellcheck disable=SC2034   # is passed by name to cleanupTmp
	readonly -a tmpPaths=(curlOutputFile)
	trap 'cleanupTmp tmpPaths' EXIT

	statusCode=$(
		curl --request POST \
			--header "PRIVATE-TOKEN: $GT_UPDATE_API_TOKEN" \
			--data-urlencode "source_branch=${sourceBranch}" \
			--data-urlencode "target_branch=${CI_DEFAULT_BRANCH}" \
			--data-urlencode "title=$commitMessage" \
			--data-urlencode "description=$mrDescription" \
			--data-urlencode "remove_source_branch=true" \
			--data-urlencode "allow_collaboration=true" \
			--output "$curlOutputFile" --write-out "%{response_code}" \
			"${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests"
	) || die "could not send the POST request for creating a merge request"

	if [[ $statusCode = 409 ]] && grep "open merge request" "$curlOutputFile"; then
		echo "There is already a merge request, no need to create another (we force pushed, so the MR is updated)"
	elif [[ "$statusCode" != 2* ]]; then
		printf >&2 "curl return http status code %s, expected 2xx. Message body:\n" "$statusCode"
		cat >&2 "$curlOutputFile"
		exit 1
	fi
}

${__SOURCED__:+return}
commitAndCreateMrOnChanges "$@"
