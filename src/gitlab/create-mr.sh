#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.17.4
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_gt_gitlab ]]; then
	dir_of_gt_gitlab="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt_gitlab
fi
source "$dir_of_gt_gitlab/utils.sh"

# shellcheck disable=SC2034   # is passed by name to exitIfEnvVarNotSet
declare -a envVars=(
	GT_UPDATE_API_TOKEN
	CI_API_V4_URL
	CI_PROJECT_ID
)
exitIfEnvVarNotSet envVars
readonly GT_UPDATE_API_TOKEN CI_API_V4_URL CI_PROJECT_ID

declare gitStatus
gitStatus=$(git status --porcelain) || {
	echo "the following command failed (see above): git status --porcelain"
	exit 1
}

if [[ $gitStatus == "" ]]; then
	echo "No git changes, i.e. no updates found, no need to create a merge request"
	exit 0
fi

echo "Detected updates, going to push changes to branch gt/update"

git branch -D "gt/update" 2 &>/dev/null || true
git checkout -b "gt/update"
git add .
git commit -m "Update files pulled via gt"
git push -f --set-upstream origin gt/update || {
	echo "could not force push gt/update to origin"
	exit 1
}

declare data
data=$(
	# shellcheck disable=SC2312
	cat <<-EOM
		{
		  "source_branch": "gt/update",
		  "target_branch": "main",
		  "title": "Changes via gt update",
		  "allow_collaboration": true,
		  "remove_source_branch": true
		}
	EOM
)

echo "Going to create a merge request for the changes"

curlOutputFile=$(mktemp -t "curl-output-XXXXXXXXXX")

# shellcheck disable=SC2034   # is passed by name to cleanupTmp
readonly -a tmpPaths=(curlOutputFile)
trap 'cleanupTmp tmpPaths' EXIT

statusCode=$(
	curl --request POST \
		--header "PRIVATE-TOKEN: $GT_UPDATE_API_TOKEN" \
		--data "$data" --header "Content-Type: application/json" \
		--output "$curlOutputFile" --write-out "%{response_code}" \
		"${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests"
) || {
	echo "could not send the POST request for creating a merge request"
	exit 1
}
if [[ $statusCode = 409 ]] && grep "open merge request" "$curlOutputFile"; then
	echo "There is already a merge request, no need to create another (we force pushed, so the MR is updated)"
elif [[ ! "$statusCode" == 2* ]]; then
	printf "curl return http status code %s, expected 2xx. Message body:\n" "$statusCode"
	cat "$curlOutputFile"
	exit 1
fi
