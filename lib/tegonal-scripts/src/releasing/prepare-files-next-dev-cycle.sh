#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.15.1
#
#######  Description  #############
#
#  prepare the next dev cycle for files based on conventions:
#  - expects a version in format vX.Y.Z(-RC...)
#  - main is your default branch
#  - requires you to have a /scripts folder in your project root which contains:
#    - before-pr.sh which provides function beforePr and updateDocu and can be sourced (add ${__SOURCED__:+return} before executing beforePr)
#
#  You can define a /scripts/additional-prepare-files-next-dev-cycle-steps.sh which is sourced (via sourceOnce) if it exists
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    # prepare dev cycle for version v0.2.0
#    "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh" -v v0.2.0
#
#    # prepare dev cycle for version v0.2.0 and
#    # searches for additional occurrences where the version should be replaced via the specified pattern in:
#    # - script files in ./src and ./scripts
#    # - ./README.md
#    "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh" -v v0.2.0 \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"
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
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v0.15.1'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/releasing/sneak-peek-banner.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/toggle-sections.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-README.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"

function prepareFilesNextDevCycle() {
	local version projectsRootDir additionalPattern
	# shellcheck disable=SC2034
	local -ra params=(
		version '-v' 'the version for which we prepare the dev cycle'
		projectsRootDir '--project-dir' '(optional) The projects directory -- default: .'
		additionalPattern '-p|--pattern' '(optional) pattern which is used in a perl command (separator /) to search & replace additional occurrences. It should define two match groups and the replace operation looks as follows: '"\\\${1}\$version\\\${2}"
	)
	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@"
	if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath ".") || die "could not determine realpath of ."; fi
	if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"

	if ! [[ "$version" =~ ^(v[0-9]+)\.([0-9]+)\.[0-9]+(-RC[0-9]+)?$ ]]; then
		die "version should match vX.Y.Z(-RC...), was %s" "$version"
	fi

	exitIfGitHasChanges

	logInfo "prepare next dev cycle for version $version"

	local -r projectsScriptsDir="$projectsRootDir/scripts"

	local -r devVersion="$version-SNAPSHOT"

	sneakPeekBanner -c show || return $?
	toggleSections -c main || return $?
	updateVersionScripts -v "$devVersion" -p "$additionalPattern" || return $?
	updateVersionScripts -v "$devVersion" -p "$additionalPattern" -d "$projectsScriptsDir" || return $?

	local -r additionalSteps="$projectsScriptsDir/additional-prepare-files-next-dev-cycle-steps.sh"
	if [[ -f $additionalSteps ]]; then
		logInfo "found $additionalSteps going to source it"
		# we are aware of that || will disable set -e for sourceOnce
		# shellcheck disable=SC2310
		sourceOnce "$additionalSteps" || die "could not source $additionalSteps"
	fi

	# we are aware of that || will disable set -e for sourceOnce
	# shellcheck disable=SC2310
	sourceOnce "$projectsScriptsDir/before-pr.sh" || die "could not source before-pr.sh"

	# check if we accidentally have broken something, run formatting or whatever is done in beforePr
	beforePr || return $?

	git commit -a -m "prepare next dev cycle for $version"
}

${__SOURCED__:+return}
prepareFilesNextDevCycle "$@"
