#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.5.1
#######  Description  #############
#
#  Releasing files based on conventions:
#  - expects a version in format vX.Y.Z(-RC...)
#  - main is your default branch (or you use --branch to define another)
#  - requires you to have a function beforePr in scope (or you define another one via --before-pr-fn)
#  - requires you to have a function prepareNextDevCycle in scope (or you define another one via --prepare-next-dev-cycle-fn)
#  - there is a public key defined at .gt/signing-key.public.asc which will be used
#    to verify the signatures which will be created
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
#    sourceOnce "$scriptsDir/before-pr.sh"
#
#    function findScripts() {
#    	find "src" -name "*.sh" -not -name "*.doc.sh" "$@"
#    }
#    # make the function visible to release-files.sh / not necessary if you source release-files.sh, see further below
#    declare -fx findScripts
#
#    # releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and function findScripts to find the files which
#    # should be signed (and thus released). Assumes that a function named beforePr is in scope (which we sourced above)
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" -v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts
#
#    # releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and function findScripts to find the files which
#     ## should be signed (and thus released). Moreover, searches for additional occurrences where the version should be
#    # replaced via the specified pattern
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"
#
#    function specialBeforePr(){
#    	beforePr && echo "imagine some additional work"
#    }
#    # make the function visible to release-files.sh / not necessary if you source prepare-files-next-dev-cycle.sh
#    # see further below
#    declare -fx specialBeforePr
#
#    # releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts \
#    	--before-pr-fn specialBeforePr
#
#
#    # in case you want to provide your own release.sh and only want to do some pre-configuration
#    # then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/release-files.sh"
#
#    # and then call the function with your pre-configuration settings:
#    # here we define the function which shall be used to find the files to be signed
#    # since "$@" follows afterwards, one could still override it via command line arguments.
#    # put "$@" first, if you don't want that a user can override your pre-configuration
#    releaseFiles --sign-fn findScripts "$@"
#
#    # call the function define --before-pr-fn, don't allow to override via command line arguments
#    releaseFiles "$@" --before-pr-fn specialBeforePr
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.5.1'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/execute-if-defined.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/release-template.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"

function releaseFiles() {
	local versionParamPatternLong projectsRootDirParamPatternLong
	local additionalPatternParamPatternLong afterVersionUpdateHookParamPatternLong releaseHookParamPatternLong
	local findForSigningParamPatternLong beforePrFnParamPatternLong prepareNextDevCycleFnParamPatternLong
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local version key findForSigning branch projectsRootDir additionalPattern
	# shellcheck disable=SC2034   # seems unused but is set in deduce-next-version
	local nextVersion
	local prepareOnly beforePrFn prepareNextDevCycleFn afterVersionUpdateHook
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" "$versionParamDocu"
		key "$keyParamPattern" "$keyParamDocu"
		findForSigning "$findForSigningParamPattern" "$findForSigningParamDocu"
		branch "$branchParamPattern" "$branchParamDocu"
		projectsRootDir "$projectsRootDirParamPattern" "$projectsRootDirParamDocu"
		additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
		nextVersion "$nextVersionParamPattern" "$nextVersionParamDocu"
		prepareOnly "$prepareOnlyParamPattern" "$prepareOnlyParamDocu"
		beforePrFn "$beforePrFnParamPattern" "$beforePrFnParamDocu"
		prepareNextDevCycleFn "$prepareNextDevCycleFnParamPattern" "$prepareNextDevCycleFnParamDocu"
		afterVersionUpdateHook "$afterVersionUpdateHookParamPattern" "$afterVersionUpdateHookParamDocu"
	)
	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@"

	# deduces nextVersion based on version if not already set (and if version set)
	source "$dir_of_tegonal_scripts/releasing/deduce-next-version.source.sh"
	if ! [[ -v branch ]]; then branch="main"; fi
	if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath "."); fi
	if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
	if ! [[ -v prepareOnly ]] || [[ $prepareOnly != "true" ]]; then prepareOnly=false; fi
	if ! [[ -v beforePrFn ]]; then beforePrFn='beforePr'; fi
	if ! [[ -v prepareNextDevCycleFn ]]; then prepareNextDevCycleFn='prepareNextDevCycle'; fi
	if ! [[ -v afterVersionUpdateHook ]]; then afterVersionUpdateHook=''; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"

	exitIfArgIsNotFunction "$findForSigning" "$findForSigningParamPatternLong"
	exitIfArgIsNotFunction "$beforePrFn" "$beforePrFnParamPatternLong"
	exitIfArgIsNotFunction "$prepareNextDevCycleFn" "$prepareNextDevCycleFnParamPatternLong"

	# those variables are used in local functions further below which will be called from releaseTemplate.
	# The problem: in case releaseTemplate defines a variable with the same name, then we would use those
	# variables instead of the one we define here, hence we prefix them to avoid this problem
	local release_files_findForSigning="$findForSigning"
	local release_files_branch="$branch"
	local release_files_projectsRootDir="$projectsRootDir"
	local release_files_afterVersionUpdateHook="$afterVersionUpdateHook"

	function releaseFiles_afterVersionHook() {
		local version projectsRootDir additionalPattern
		parseArguments afterVersionHookParams "" "$TEGONAL_SCRIPTS_VERSION" "$@"

		updateVersionScripts \
			"$versionParamPatternLong" "$version" \
			"$additionalPatternParamPatternLong" "$additionalPattern" \
			-d "$projectsRootDir/src" || return $?

		executeIfFunctionNameDefined "$release_files_afterVersionUpdateHook" "$afterVersionUpdateHookParamPatternLong" \
			"$versionParamPatternLong" "$version" \
			"$projectsRootDirParamPatternLong" "$projectsRootDir" \
			"$additionalPatternParamPatternLong" "$additionalPattern"
	}

	function releaseFiles_releaseHook() {
		local -r gtDir="$release_files_projectsRootDir/.gt"
		local -r gpgDir="$gtDir/gpg"
		if ! rm -rf "$gpgDir"; then
			logError "was not able to remove gpg directory %s\nPlease do this manually and re-run the release command" "$gpgDir"
			git reset --hard "origin/$release_files_branch"
		fi
		mkdir "$gpgDir"
		chmod 700 "$gpgDir"

		gpg --homedir "$gpgDir" --batch --no-tty --import "$gtDir/signing-key.public.asc" || die "was not able to import %s" "$gtDir/signing-key.public.asc"
		trustGpgKey "$gpgDir" "info@tegonal.com" || logInfo "could not trust key with id info@tegonal.com, you will see warnings due to this during signing the files"

		local script
		"$release_files_findForSigning" -type f -not -name "*.sig" -print0 |
			while read -r -d $'\0' script; do
				echo "signing $script"
				gpg --detach-sign --batch --no-tty --yes -u "$key" -o "${script}.sig" "$script" || die "was not able to sign %s" "$script"
				gpg --homedir "$gpgDir" --batch --no-tty --verify "${script}.sig" "$script" || die "verification via previously imported %s failed" "$gtDir/signing-key.public.asc"
			done || return $?
	}

	releaseTemplate \
		"$@" \
		"$releaseHookParamPatternLong" releaseFiles_releaseHook \
		"$afterVersionUpdateHookParamPatternLong" releaseFiles_afterVersionHook
}

${__SOURCED__:+return}
releaseFiles "$@"
