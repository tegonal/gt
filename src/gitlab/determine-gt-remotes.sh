#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v2.1.0-SNAPSHOT
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
if ! [[ -v dir_of_gt_gitlab ]]; then
	dir_of_gt_gitlab="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt_gitlab
fi
if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$dir_of_gt_gitlab/../../../../")"
	readonly projectDir
fi
source "$dir_of_gt_gitlab/utils.sh"

function determineGtRemotes() {

	# shellcheck disable=SC2034   # is passed by name to exitIfEnvVarNotSet
	local -a envVars=(
		# actually not needed here but in the remote jobs. We check it here as it doesn't make sense to trigger the remote
		# jobs if we know that they will fail because the env variable is missing
		GT_UPDATE_API_TOKEN
	)
	exitIfEnvVarNotSet envVars

	local -r relativePathToSetupYaml=".gitlab/.gitlab-gt-update-remote-own-setup.yml"
	local additionalInclude=""
	local extends=""
	if [[ -f "$projectDir/$relativePathToSetupYaml" ]]; then
		additionalInclude="- local: $relativePathToSetupYaml"
		extends="- .gt-update-remote-own-setup"
	fi

	cat <<-EOF
		include:
		  - local: lib/gt/src/gitlab/.gitlab-gt-common.yml
		  $additionalInclude
	EOF

	local remote
	gt remote list | while read -r remote; do
		cat <<-EOF
			update-${remote}:
			  extends:
			    - .gt-update-remote-template
			    ${extends}
			  variables:
			    REMOTE_NAME: "${remote}"
		EOF
	done
}
${__SOURCED__:+return}
determineGtRemotes "$@"
