#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.18.0
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
GT_VERSION="v0.18.0"

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	readonly projectDir
fi

if ! [[ -v dir_of_github_commons ]]; then
	dir_of_github_commons="$projectDir/lib/tegonal-gh-commons/src"
	readonly dir_of_github_commons
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_github_commons/gt/pull-hook-functions.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function updateVersionInNonShFiles() {
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || die "could not source common-constants.source.sh"
	local version projectsRootDir additionalPattern
	parseArguments afterVersionHookParams "" "$GT_VERSION" "$@"

	local -ra additionalScripts=(
		"$projectsRootDir/install.sh"
	)

	for script in "${additionalScripts[@]}"; do
		updateVersionScripts -v "$version" -p "$additionalPattern" -d "$script"
	done

	local -ra additionalFilesWithVersions=(
		"$projectDir/.github/workflows/gt-update.yml"
	)

	logInfo "going to update version in non-sh files to %s" "$version"
	for file in "${additionalFilesWithVersions[@]}"; do
		perl -0777 -i -pe "s/(# {4,}Version: ).*/\${1}$version/g;" "$file"
	done
}

${__SOURCED__:+return}
updateVersionInNonShFiles "$@"
