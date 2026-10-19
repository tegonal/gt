#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.2.0
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
#    source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
#
#    scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
#    sourceOnce "$scriptsDir/before-pr.sh"
#
#    # prepare dev cycle for version v0.2.0, assumes a function beforePr is in scope which we sourced above
#    "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle-template.sh" -v v0.2.0
#
#    function specialBeforePr() {
#    	beforePr && echo "imagine some additional work"
#    }
#    # make the function visible to prepare-files-next-dev-cycle-template.sh / not necessary if you source
#    # prepare-files-next-dev-cycle-template.sh, see further below
#    declare -fx specialBeforePr
#
#    # prepare dev cycle for version v0.2.0 and
#    # searches for additional occurrences where the version should be replaced via the specified pattern in:
#    # - script files in ./src and ./scripts
#    # - ./README.md
#    # uses specialBeforePr instead of beforePr
#    "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle-template.sh" \
#    	-v v0.2.0 -p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])" --before-pr-fn specialBeforePr
#
#    # in case you want to provide your own release.sh and only want to do some pre-configuration
#    # then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle-template.sh"
#
#    # and then call the function with your pre-configuration settings:
#    # here we define the pattern which shall be used to replace further version occurrences
#    # since "$@" follows afterwards, one could still override it via command line arguments.
#    # put "$@" first, if you don't want that a user can override your pre-configuration
#    prepareFilesNextDevCycleTemplate -p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])" "$@"
#
#    # call the function define --before-pr-fn, don't allow to override via command line arguments
#    prepareFilesNextDevCycleTemplate "$@" --before-pr-fn specialBeforePr
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v5.2.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/execute-if-defined.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-next-dev-cycle-template.sh"

function prepareFilesNextDevCycleTemplate() {
	source "$dir_of_tegonal_scripts/releasing/params/prepare-files-next-dev-cycle-template.params.source.sh" || traceAndDie "could not source prepare-files-next-dev-cycle-template.params.source.sh"
	source "$dir_of_tegonal_scripts/releasing/params/prepare-files-next-dev-cycle-template.params-definition.source.sh" || traceAndDie "could not source prepare-files-next-dev-cycle-template.params-definition.source.sh"
	parseArguments prepareFilesNextDevCycleTemplateParams "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	source "$dir_of_tegonal_scripts/releasing/params/prepare-files-next-dev-cycle-template.default-args.source.sh" || traceAndDie "could not source prepare-files-next-dev-cycle-template.default-args.source.sh"
	exitIfNotAllArgumentsSet prepareFilesNextDevCycleTemplateParams "" "$TEGONAL_SCRIPTS_VERSION"
	exitIfArgIsNotVersion "$version" "$versionParamPatternLong"
	exitIfArgIsNotFunction "$beforePrFn" "$beforePrFnParamPatternLong"

	local -a prepareNextDevCycleTemplateArgs
	addLocalVarMatchingParamNamesToArgs prepareNextDevCycleTemplateParams prepareNextDevCycleTemplateArgs

	local -a afterVersionHookArgs
	addLocalVarMatchingParamNamesToArgs afterVersionHookParams afterVersionHookArgs

	# those variables are used in local functions further below which will be called from releaseTemplate.
	# The problem: in case releaseTemplate defines a variable with the same name, then we would use those
	# variables instead of the one we define here, hence we prefix them to avoid this problem
	local prepare_files_next_dev_afterVersionUpdateHook="$afterVersionUpdateHook"

	function prepareFilesNextDevCycleTemplate_afterVersionHook() {
		source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params.source.sh" || traceAndDie "could not source after-version-update-hook.params.source.sh"
		source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params-definition.source.sh" || traceAndDie "could not source after-version-update-hook.params-definition.source.sh"
		parseArguments afterVersionHookParams "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
		exitIfNotAllArgumentsSet afterVersionHookParams "" "$TEGONAL_SCRIPTS_VERSION"

		local -a afterVersionHookArgs
		addLocalVarMatchingParamNamesToArgs afterVersionHookParams afterVersionHookArgs

		updateVersionScripts \
			"$versionParamPatternLong" "$version-SNAPSHOT" \
			"$additionalPatternParamPatternLong" "$additionalPattern" \
			-d "$projectsRootDir/src" || return $?

		executeIfFunctionNameDefined "$prepare_files_next_dev_afterVersionUpdateHook" "$afterVersionUpdateHookParamPatternLong" \
			"${afterVersionHookArgs[@]}"
	}

	prepareNextDevCycleTemplate \
		"${prepareNextDevCycleTemplateArgs[@]}" \
		"$afterVersionUpdateHookParamPatternLong" prepareFilesNextDevCycleTemplate_afterVersionHook
}

${__SOURCED__:+return}
prepareFilesNextDevCycleTemplate "$@"
