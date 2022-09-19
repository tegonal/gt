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
GGET_LATEST_VERSION="v0.7.1"

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../../../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

if ! [[ -v dir_of_github_commons ]]; then
	dir_of_github_commons="$dir_of_tegonal_scripts/../../../.gget/remotes/tegonal-gh-commons/lib/src"
	readonly dir_of_github_commons
fi

sourceOnce "$dir_of_github_commons/gget/pull-hook-functions.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function gget_pullHook_tegonal_gh_commons_before() {
	local _tag source _target
	# shellcheck disable=SC2034
	local -ra params=(_tag source _target)
	parseFnArgs params "$@"

	if [[ $source =~ .*/\.github/Contributor[[:space:]]Agreement\.txt ]]; then
		replacePlaceholdersContributorsAgreement "$source" "gget"
	elif [[ $source =~ .*/\.github/PULL_REQUEST_TEMPLATE.md ]]; then
		# same as in additional-release-files-preparations.sh
		local -r githubUrl="https://github.com/tegonal/gget"
		replacePlaceholderPullRequestTemplate "$source" "$githubUrl" "$GGET_LATEST_VERSION"
	fi
}

function gget_pullHook_tegonal_gh_commons_after() {
	local _tag source target
	# shellcheck disable=SC2034
	local -ra params=(_tag source target)
	parseFnArgs params "$@"

	if [[ $source =~ .*/src/gget/signing-key.public.asc.actual_sig ]]; then
		mv "$target" "$(dirname "$target")/signing-key.public.asc.sig"
	fi
}
