#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v3.0.1
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
sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle-template.sh"
sourceOnce "$scriptsDir/before-pr.sh"
sourceOnce "$scriptsDir/update-version-in-non-sh-files.sh"

function prepareNextDevCycle() {
	source "$dir_of_tegonal_scripts/releasing/params/prepare-files-next-dev-cycle.params.source.sh" || traceAndDie "could not source prepare-files-next-dev-cycle.params.source.sh"
	source "$dir_of_tegonal_scripts/releasing/params/prepare-files-next-dev-cycle.params-definition.source.sh" || traceAndDie "could not source prepare-files-next-dev-cycle.params-definition.source.sh"
	parseArguments prepareFilesNextDevCycleParams "" "$GT_VERSION" "$@" || return $?
	source "$dir_of_tegonal_scripts/releasing/params/prepare-files-next-dev-cycle.default-args.source.sh" || die "could not source prepare-files-next-dev-cycle.default-args.source.sh"
	exitIfNotAllArgumentsSet prepareFilesNextDevCycleParams "" "$GT_VERSION"

	local -a prepareFilesNextDevCycleTemplateArgs
	addLocalVarMatchingParamNamesToArgs prepareFilesNextDevCycleTemplateParams prepareFilesNextDevCycleTemplateArgs

	function prepare_next_afterVersionHook() {
		source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params.source.sh" || traceAndDie "could not source after-version-update-hook.params.source.sh"
		source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params-definition.source.sh" || traceAndDie "could not source after-version-update-hook.params-definition.source.sh"
		parseArguments afterVersionHookParams "" "$GT_VERSION" "$@" || return $?
		exitIfNotAllArgumentsSet afterVersionHookParams "" "$GT_VERSION"

		local -a updateVersionInNonShFilesArgs
		addLocalVarMatchingParamNamesToArgs afterVersionHookParams updateVersionInNonShFilesArgs

		updateVersionInNonShFiles "${updateVersionInNonShFilesArgs[@]}" -v "$version-SNAPSHOT"
	}

	# similar as in release.sh, you might need to update it there as well if you change something here
	# we only update the version in the header but not the GT_LATEST_VERSION on purpose because we don't want to set the SNAPSHOT
	# version since this would cause that we set the SNAPSHOT version next time we update files via gt
	local -r ownAdditionalPattern="(GT_VERSION=['\"])[^'\"]+(['\"])"

	prepareFilesNextDevCycleTemplate "${prepareFilesNextDevCycleTemplateArgs[@]}" \
		"$additionalPatternParamPatternLong" "$ownAdditionalPattern" \
		"$afterVersionUpdateHookParamPatternLong" prepare_next_afterVersionHook

}

${__SOURCED__:+return}
prepareNextDevCycle "$@"
