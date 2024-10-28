#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.0.1
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
GT_VERSION="v1.0.1"

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	readonly projectDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh"
sourceOnce "$scriptsDir/before-pr.sh"
sourceOnce "$scriptsDir/update-version-in-non-sh-files.sh"

function prepareNextDevCycle() {
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	# shellcheck disable=SC2034   # they seem unused but are necessary in order that parseArguments doesn't create global readonly vars
	local version projectsRootDir additionalPattern beforePrFn
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" 'the version for which we prepare the dev cycle'
		projectsRootDir "$projectsRootDirParamPattern" "$projectsRootDirParamDocu"
		additionalPattern "$additionalPatternParamPattern" "is ignored as additional pattern is specified internally, still here as release-files uses this argument"
		beforePrFn "$beforePrFnParamPattern" "$beforePrFnParamDocu"
	)
	parseArguments params "" "$GT_VERSION" "$@"
	# we don't check if all args are set (and neither set default values) as we currently don't use
	# any param in here but just delegate to prepareFilesNextDevCycle.

	function prepare_next_afterVersionHook() {
		local version projectsRootDir additionalPattern
		parseArguments afterVersionHookParams "" "$GT_VERSION" "$@"

		updateVersionInNonShFiles -v "$version-SNAPSHOT" --project-dir "$projectsRootDir" --pattern "$additionalPattern"
	}

	# similar as in release.sh, you might need to update it there as well if you change something here
	# we only update the version in the header but not the GT_LATEST_VERSION on purpose because we don't want to set the SNAPSHOT
	# version since this would cause that we set the SNAPSHOT version next time we update files via gt
	local -r additionalPattern="(GT_VERSION=['\"])[^'\"]+(['\"])"

	prepareFilesNextDevCycle \
		--project-dir "$projectDir" \
		"$@" \
		--pattern "$additionalPattern" \
		--after-version-update-hook prepare_next_afterVersionHook
}

${__SOURCED__:+return}
prepareNextDevCycle "$@"
