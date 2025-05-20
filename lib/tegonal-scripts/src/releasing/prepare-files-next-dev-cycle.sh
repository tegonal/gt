#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.1
#######  Description  #############
#
#  Prepare the next dev cycle for files based on conventions:
#  - expects a version in format vX.Y.Z(-RC...)
#  - main is your default branch (or you specify --branch)
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
#    sourceOnce "$scriptsDir/before-pr.sh"
#
#    # prepare dev cycle for version v0.2.0, assumes a function beforePr is in scope which we sourced above
#    "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh" -v v0.2.0
#
#    function specialBeforePr(){
#    	beforePr && echo "imagine some additional work"
#    }
#    # make the function visible to release-files.sh / not necessary if you source prepare-files-next-dev-cycle.sh, see further below
#    declare -fx specialBeforePr
#
#    # prepare dev cycle for version v0.2.0 and
#    # searches for additional occurrences where the version should be replaced via the specified pattern in:
#    # - script files in ./src and ./scripts
#    # - ./README.md
#    # uses specialBeforePr instead of beforePr
#    "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh" -v v0.2.0 \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])" \
#    	--before-pr-fn specialBeforePr
#
#    # in case you want to provide your own release.sh and only want to do some pre-configuration
#    # then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh"
#
#    # and then call the function with your pre-configuration settings:
#    # here we define the pattern which shall be used to replace further version occurrences
#    # since "$@" follows afterwards, one could still override it via command line arguments.
#    # put "$@" first, if you don't want that a user can override your pre-configuration
#    prepareNextDevCycle -p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])" "$@"
#
#    # call the function define --before-pr-fn, don't allow to override via command line arguments
#    prepareNextDevCycle "$@" --before-pr-fn specialBeforePr
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.8.1'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/execute-if-defined.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-next-dev-cycle-template.sh"

function prepareFilesNextDevCycle() {
	local versionParamPatternLong projectsRootDirParamPatternLong
	local additionalPatternParamPatternLong beforePrFnParamPatternLong afterVersionUpdateHookParamPatternLong
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local version afterVersionUpdateHook projectsRootDir additionalPattern beforePrFn afterVersionUpdateHook
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" 'the version for which we prepare the dev cycle'
		projectsRootDir "$projectsRootDirParamPattern" "$projectsRootDirParamDocu"
		additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
		beforePrFn "$beforePrFnParamPattern" "$beforePrFnParamDocu"
		afterVersionUpdateHook "$afterVersionUpdateHookParamPattern" "$afterVersionUpdateHookParamDocu"
	)
	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath ".") || die "could not determine realpath of ."; fi
	if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
	if ! [[ -v beforePrFn ]]; then beforePrFn="beforePr"; fi
	if ! [[ -v afterVersionUpdateHook ]]; then afterVersionUpdateHook=''; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"

	exitIfArgIsNotFunction "$beforePrFn" "$beforePrFnParamPatternLong"

	# those variables are used in local functions further below which will be called from releaseTemplate.
	# The problem: in case releaseTemplate defines a variable with the same name, then we would use those
	# variables instead of the one we define here, hence we prefix them to avoid this problem
	local prepare_files_next_dev_afterVersionUpdateHook="$afterVersionUpdateHook"

	function prepareFilesNextDevCycle_afterVersionHook() {
		local version projectsRootDir additionalPattern
		parseArguments afterVersionHookParams "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?

		updateVersionScripts \
			"$versionParamPatternLong" "$version-SNAPSHOT" \
			"$additionalPatternParamPatternLong" "$additionalPattern" \
			-d "$projectsRootDir/src" || return $?

		executeIfFunctionNameDefined "$prepare_files_next_dev_afterVersionUpdateHook" "$afterVersionUpdateHookParamPatternLong" \
			"$versionParamPatternLong" "$version" \
			"$projectsRootDirParamPatternLong" "$projectsRootDir" \
			"$additionalPatternParamPatternLong" "$additionalPattern"
	}

	prepareNextDevCycleTemplate \
		"$@" \
		"$afterVersionUpdateHookParamPatternLong" prepareFilesNextDevCycle_afterVersionHook
}

${__SOURCED__:+return}
prepareFilesNextDevCycle "$@"
