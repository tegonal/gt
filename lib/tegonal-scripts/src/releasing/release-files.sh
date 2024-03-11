#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v2.0.0
#######  Description  #############
#
#  Releasing files based on conventions:
#  - expects a version in format vX.Y.Z(-RC...)
#  - main is your default branch
#  - requires you to have a /scripts folder in your project root which contains:
#    - before-pr.sh which provides a parameterless function beforePr and can be sourced (add ${__SOURCED__:+return} before executing beforePr)
#    - prepare-next-dev-cycle.sh which provides function prepareNextDevCycle and can be sourced
#  - there is a public key defined at .gt/signing-key.public.asc which will be used
#    to verify the signatures which will be created
#
#  You can define /scripts/additional-release-files-preparations.sh which is sourced (via sourceOnce) if it exists.
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
#    function findScripts() {
#    	find "src" -name "*.sh" -not -name "*.doc.sh" "$@"
#    }
#    # make the function visible to release-files.sh / not necessary if you source release-files.sh, see further below
#    declare -fx findScripts
#
#    # releases version v0.1.0 using the key 0x945FE615904E5C85 for signing
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" -v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts
#
#    # releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and
#    # searches for additional occurrences where the version should be replaced via the specified pattern in:
#    # - script files in ./src and ./scripts
#    # - ./README.md
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"
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
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v2.0.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/pre-release-checks-git.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/release-tag-prepare-next-push.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/sneak-peek-banner.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/toggle-sections.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-common-steps.sh"

function releaseFiles() {
	local versionParamPatternLong branchParamPatternLong projectsRootDirParamPatternLong
	local additionalPatternParamPatternLong nextVersionParamPatternLong prepareOnlyParamPatternLong
	source "$dir_of_tegonal_scripts/releasing/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	local version branch key findForSigning projectsRootDir additionalPattern nextVersion prepareOnly
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
	)

	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@"

	# deduces nextVersion based on version if not already set (and if version set)
	source "$dir_of_tegonal_scripts/releasing/deduce-next-version.source.sh"
	if ! [[ -v branch ]]; then branch="main"; fi
	if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath "."); fi
	if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
	if ! [[ -v prepareOnly ]] || [[ $prepareOnly != "true" ]]; then prepareOnly=false; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"

	exitIfArgIsNotFunction "$findForSigning" "--sign-fn"

	preReleaseCheckGit \
		"$versionParamPatternLong" "$version" \
		"$branchParamPatternLong" "$branch"

	local -r projectsScriptsDir="$projectsRootDir/scripts"
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for sourceOnce
	sourceOnce "$projectsScriptsDir/before-pr.sh" || die "could not source before-pr.sh"

	# make sure everything is up-to-date and works as it should
	beforePr || return $?

	updateVersionCommonSteps \
		"$versionParamPatternLong" "$version" \
		"$projectsRootDirParamPatternLong" "$projectsRootDir" \
		"$additionalPatternParamPatternLong" "$additionalPattern"

	local -r additionalSteps="$projectsScriptsDir/additional-release-files-preparations.sh"
	if [[ -f $additionalSteps ]]; then
		logInfo "found $additionalSteps going to source it"
		# shellcheck disable=SC2310				# we are aware of that || will disable set -e for sourceOnce
		sourceOnce "$additionalSteps" || die "could not source $additionalSteps"
	fi

	# run again since we made changes
	beforePr || return $?

	local -r gtDir="$projectsRootDir/.gt"
	local -r gpgDir="$gtDir/gpg"
	if ! rm -rf "$gpgDir"; then
		logError "was not able to remove gpg directory %s\nPlease do this manually and re-run the release command" "$gpgDir"
		git reset --hard "origin/$branch"
	fi
	mkdir "$gpgDir"
	chmod 700 "$gpgDir"

	gpg --homedir "$gpgDir" --batch --no-tty --import "$gtDir/signing-key.public.asc" || die "was not able to import %s" "$gtDir/signing-key.public.asc"
	trustGpgKey "$gpgDir" "info@tegonal.com" || logInfo "could not trust key with id info@tegonal.com, you will see warnings due to this during signing the files"

	local script
	"$findForSigning" -type f -not -name "*.sig" -print0 |
		while read -r -d $'\0' script; do
			echo "signing $script"
			gpg --detach-sign --batch --no-tty --yes -u "$key" -o "${script}.sig" "$script" || die "was not able to sign %s" "$script"
			gpg --homedir "$gpgDir" --batch --no-tty --verify "${script}.sig" "$script" || die "verification via previously imported %s failed" "$gtDir/signing-key.public.asc"
		done || return $?

	if [[ $prepareOnly != true ]]; then
		releaseTagPrepareNextAndPush \
			"$versionParamPatternLong" "$version" \
			"$branchParamPatternLong" "$branch" \
			"$projectsRootDirParamPatternLong" "$projectsRootDir" \
			"$additionalPatternParamPatternLong" "$additionalPattern" \
			"$nextVersionParamPatternLong" "$nextVersion"
	else
		printf "\033[1;33mskipping commit, creating tag and prepare-next-dev-cycle due to %s\033[0m\n" "$prepareOnlyParamPatternLong"
	fi
}

${__SOURCED__:+return}
releaseFiles "$@"
