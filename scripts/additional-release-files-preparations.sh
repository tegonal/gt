#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.6.0-SNAPSHOT
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	readonly projectDir
fi

if ! [[ -v dir_of_github_commons ]]; then
	dir_of_github_commons="$projectDir/.gget/remotes/tegonal-gh-commons/lib/src"
	readonly dir_of_github_commons
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_github_commons/gget/pull-hook-functions.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"

function additionalReleasePrepareSteps() {
	# keep in sync with local -r
	exitIfVarsNotAlreadySetBySource version additionalPattern
	# we help shellcheck to realise that version and additionalPattern are initialised
	local -r version="$version" additionalPattern="$additionalPattern"

	# same as in pull-hook.sh
	local -r githubUrl="https://github.com/tegonal/gget"
	replaceTagInPullRequestTemplate "$projectDir/.github/PULL_REQUEST_TEMPLATE.md" "$githubUrl" "$version"

	local -ra additionalScripts=(
		"$projectDir/install.sh"
		"$projectDir/.gget/remotes/tegonal-gh-commons/pull-hook.sh"
	)
	for script in "${additionalScripts[@]}"; do
		updateVersionScripts -v "$version" -p "$additionalPattern" -d "$script"
	done
}
additionalReleasePrepareSteps
