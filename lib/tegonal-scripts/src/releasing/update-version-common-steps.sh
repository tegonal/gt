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
#  Carry out some common update version steps either during releasing or in preparing the next dev cycle (indicated via
#  --for-release true/false
#
#  It carries out the following steps
#  - hide/show the sneak peek banner
#  - show release section and hide main section (or the opposite in case --for-release false)
#  - update version in script headers
#  - update links and version in README.md (see update-version-README.sh)
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
#    # updates the version in headers of different files, hides the sneak-peek banner and
#    # toggles sections in README.md for release
#    "$dir_of_tegonal_scripts/releasing/update-version-common-steps.sh" --for-release true -v v0.1.0
#
#    # 1. searches for additional occurrences where the version should be replaced via the specified pattern
#    # 2. git commit all changes and create a tag for v0.1.0
#    # 3. call scripts/prepare-next-dev-cycle.sh with nextVersion deduced from the specified version (in this case 0.2.0-SNAPSHOT)
#    # 4. git commit all changes as prepare v0.2.0 dev cycle
#    # 5. push tag and commits
#    # 6. releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and
#    "$dir_of_tegonal_scripts/releasing/update-version-common-steps.sh" \
#    	--for-release true \
#    	-v v0.1.0 -k "0x945FE615904E5C85" \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"
#
#    # in case you want to provide your own release.sh and only want to do some pre-configuration
#    # then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-common-steps.sh"
#
#    # and then call the function with your pre-configuration settings:
#    # here we pre-define the additional pattern which shall be used in the search to replace the version
#    # since "$@" follows afterwards, one could still override it via command line arguments.
#    # put "$@" first, if you don't want that a user can override your pre-configuration
#    updateVersionCommonSteps -p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])" "$@"
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
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/sneak-peek-banner.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/toggle-sections.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-issue-templates.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-README.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"

function updateVersionCommonSteps() {
	local forReleaseParamPatternLong versionParamPatternLong additionalPatternParamPatternLong
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local forRelease version projectsRootDir additionalPattern
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		forRelease "$forReleaseParamPattern" "$forReleaseParamDocu"
		version "$versionParamPattern" "$versionParamDocu"
		projectsRootDir "$projectsRootDirParamPattern" "$projectsRootDirParamDocu"
		additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
	)
	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?

	if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath "."); fi
	if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"
	exitIfArgIsNotBoolean "$forRelease" "$forReleaseParamPatternLong"

	local -r projectsScriptsDir="$projectsRootDir/scripts"

	if [[ $forRelease = true ]]; then
		sneakPeekBanner -c hide || return $?
		toggleSections -c release || return $?
	else
		sneakPeekBanner -c show || return $?
		toggleSections -c main || return $?
	fi

	updateVersionScripts \
		"$versionParamPatternLong" "$version" \
		"$additionalPatternParamPatternLong" "$additionalPattern" \
		-d "$projectsScriptsDir" || return $?

	find "$projectsRootDir/.gt" -name "pull-hook.sh" -print0 |
		while read -r -d $'\0' script; do
			updateVersionScripts \
				"$versionParamPatternLong" "$version" \
				"$additionalPatternParamPatternLong" "$additionalPattern" \
				-d "$script" || return $?
		done

	if [[ $forRelease = true ]]; then
		updateVersionReadme \
			"$versionParamPatternLong" "$version" \
			"$additionalPatternParamPatternLong" "$additionalPattern" || return $?

		local -r templateDir="$projectsRootDir/./.github/ISSUE_TEMPLATE"
		if [[ -d "$templateDir" ]]; then
			updateVersionIssueTemplates "$versionParamPatternLong" "$version" -d "$templateDir"
		fi
	fi
}

${__SOURCED__:+return}
updateVersionCommonSteps "$@"
