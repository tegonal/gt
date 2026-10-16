#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v3.1.0-SNAPSHOT
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
GT_VERSION="v3.1.0-SNAPSHOT"

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi
source "$scriptsDir/dirs.source.sh"
sourceOnce "$dir_of_github_commons/gt/pull-hook-functions.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function updateVersionInNonShFiles() {
	source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params.source.sh" || traceAndDie "could not source after-version-update-hook.params.source.sh"
	source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params-definition.source.sh" || traceAndDie "could not source after-version-update-hook.params-definition.source.sh"
	parseArguments afterVersionHookParams "" "$GT_VERSION" "$@" || return $?
	exitIfNotAllArgumentsSet afterVersionHookParams "" "$GT_VERSION"

	local -ra additionalScripts=(
		"$projectsRootDir/install.sh"
	)

	for script in "${additionalScripts[@]}"; do
		[[ -f $script ]] || die "looks like the additional script %s no longer exists" "$script"
		updateVersionScripts -v "$version" -p "$additionalPattern" -d "$script" || die "could not update version in additional script %s" "$script"
	done

	local -ra additionalFilesWithVersions=(
		"$projectDir/.github/workflows/gt-update.yml"
		"$projectDir/src/gitlab/.gitlab-gt.yml"
		"$projectDir/src/gitlab/.gitlab-gt-common.yml"
		"$projectDir/src/install/zsh/_gt"
	)

	logInfo "going to update version in non-sh files to %s" "$version"
	for file in "${additionalFilesWithVersions[@]}"; do
		[[ -f $file ]] || die "looks like the non-sh file %s no longer exists" "$file"
		perl -0777 -i -pe "s/(# {4,}Version: ).*/\${1}$version/g;" "$file" || die "could not update version in non-sh file %s" "$script"
	done
}

${__SOURCED__:+return}
updateVersionInNonShFiles "$@"
