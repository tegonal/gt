#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.10.0
#######  Description  #############
#
#  Prepares the next dev cycle based on conventions:
#  - expects a version in format vX.Y.Z(-RC...)
#  - main is your default branch (or you specify --branch)
#
#  It then executes the following steps:
#  - update-version-common-steps.sh (see corresponding file for more information)
#  - afterVersionUpateHook if defined
#  - beforePrFn to see if everything is still OK
#  - commits the changes
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
#    function prepareNextAfterVersionUpdateHook() {
#    	# some additional version bumps e.g. using perl
#    	perl -0777 -i #...
#    }
#    # make the function visible to prepare-next-dev-cycle-templates.sh / not necessary if you source it, see further below
#    declare -fx prepareNextAfterVersionUpdateHook
#
#    # prepare version 0.1.0 dev cycle
#    "$dir_of_tegonal_scripts/releasing/prepare-next-dev-cycle-templates.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --after-version-update-hook prepareNextAfterVersionUpdateHook
#
#    # prepare version 0.1.0 dev cycle
#    # searches for additional occurrences where the version should be replaced via the specified pattern in:
#    # - script files in ./src and ./scripts
#    # - ./README.md
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --after-version-update-hook prepareNextAfterVersionUpdateHook \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"
#
#    # in case you want to provide your own prepare-next-dev-cycle.sh and only want to do some pre-configuration
#    # (such as specify the after-version-hook) then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-next-dev-cycle-templates.sh.sh"
#
#    # and then call the function with your pre-configuration settings:
#    # here we define the function which shall be used as after-version-update-hook after "$@", this way one cannot
#    # override it. put --after-version-update-hook before "$@" if you want to define only a default
#    prepareNextDevCycleTemplate "$@" --after-version-update-hook prepareNextAfterVersionUpdateHook
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.10.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/execute-if-defined.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-common-steps.sh"

function prepareNextDevCycleTemplate() {
	local versionRegex versionParamPatternLong projectsRootDirParamPatternLong
	local additionalPatternParamPatternLong beforePrFnParamPatternLong afterVersionUpdateHookParamPatternLong
	local forReleaseParamPatternLong
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local version projectsRootDir additionalPattern beforePrFn afterVersionUpdateHook
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" 'the version for which we prepare the dev cycle'
		projectsRootDir "$projectsRootDirParamPattern" "$projectsRootDirParamDocu"
		additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
		beforePrFn "$beforePrFnParamPattern" "$beforePrFnParamDocu"
		afterVersionUpdateHook "$afterVersionUpdateHookParamPattern" "$afterVersionUpdateHookParamDocu"
	)
	parseArgumentsIgnoreUnknown params "" "$TEGONAL_SCRIPTS_VERSION" "$@"
	if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath ".") || die "could not determine realpath of ."; fi
	if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
	if ! [[ -v beforePrFn ]]; then beforePrFn="beforePr"; fi
	if ! [[ -v afterVersionUpdateHook ]]; then afterVersionUpdateHook=''; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"
	exitIfArgIsNotVersion "$version" "$versionParamPatternLong"
	exitIfArgIsNotFunction "$beforePrFn" "$beforePrFnParamPatternLong"

	exitIfGitHasChanges

	logInfo "prepare next dev cycle for version $version"

	local -r devVersion="$version-SNAPSHOT"

	updateVersionCommonSteps \
		"$forReleaseParamPatternLong" false \
		"$versionParamPatternLong" "$devVersion" \
		"$projectsRootDirParamPatternLong" "$projectsRootDir" \
		"$additionalPatternParamPatternLong" "$additionalPattern"

	executeIfFunctionNameDefined "$afterVersionUpdateHook" "$afterVersionUpdateHookParamPatternLong" \
		"$versionParamPatternLong" "$version" \
		"$projectsRootDirParamPatternLong" "$projectsRootDir" \
		"$additionalPatternParamPatternLong" "$additionalPattern"

	# check if we accidentally have broken something, run formatting or whatever is done in beforePr
	"$beforePrFn" || return $?

	git commit -a -m "prepare next dev cycle for $version"
}

${__SOURCED__:+return}
prepareNextDevCycleTemplate "$@"
