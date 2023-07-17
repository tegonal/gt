#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.13.0-SNAPSHOT
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
	dir_of_github_commons="$projectDir/.gt/remotes/tegonal-gh-commons/lib/src"
	readonly dir_of_github_commons
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_github_commons/gt/pull-hook-functions.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-issue-templates.sh"

function additionalReleasePrepareSteps() {
	# keep in sync with local -r further below (3 lines at the time of writing)
	exitIfVarsNotAlreadySetBySource version additionalPattern
	# we help shellcheck to realise that these variables are initialised
	local -r version="$version" additionalPattern="$additionalPattern"

	logInfo "going to update version in non-sh files to %s" "$version"
	local -ra additionalFilesWithVersions=(
		"$projectDir/.github/workflows/gt-update.yml"
	)
	for file in "${additionalFilesWithVersions[@]}"; do
		perl -0777 -i -pe "s/(# {4,}Version: ).*/\${1}$version/g;" "$file"
	done

	# same as in pull-hook.sh
	local -r githubUrl="https://github.com/tegonal/gt"
	replaceTagInPullRequestTemplate "$projectDir/.github/PULL_REQUEST_TEMPLATE.md" "$githubUrl" "$version" || die "could not fill the placeholders in PULL_REQUEST_TEMPLATE.md"

	updateVersionIssueTemplates -v "$version"

	local -ra additionalScripts=(
		"$projectDir/install.sh"
		"$projectDir/.gt/remotes/tegonal-gh-commons/pull-hook.sh"
	)
	for script in "${additionalScripts[@]}"; do
		updateVersionScripts -v "$version" -p "$additionalPattern" -d "$script"
	done
}
additionalReleasePrepareSteps
