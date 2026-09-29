#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.13.0-SNAPSHOT
#######  Description  #############
#
#  Defines a release process template where some conventions are defined:
#  - expects a version in format vX.Y.Z(-RC...)
#  - main is your default branch (or you use --branch to define another)
#  - requires you to have a function beforePr in scope (or you define another one via --before-pr-fn)
#  - requires you to have a function prepareNextDevCycle in scope (or you define another one via --prepare-next-dev-cycle-fn)
#
#  It then executes the following steps:
#  - check git is OK (see pre-release-checks-git.sh)
#  - check beforePrFn can be executed without problems
#  - update versions, badges, download links and more (see update-version-common-steps.sh)
#  - call the afterVersionUpdateHook if defined
#  - check again beforePrFn is not broken
#  - call the releaseHook
#  - commit and tag
#  - call prepareNextDevCycleFn
#  - push commits and tag
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
#    function releaseScalaLib() {
#    	sbt publishSigned
#    	# or
#    	sbt test publishedSigned
#    }
#    # make the function visible to release-templates.sh / not necessary if you source release-templates.sh, see further below
#    declare -fx releaseScalaLib
#
#    # releases version v0.1.0 using releaseScalaLib as hook
#    "$dir_of_tegonal_scripts/releasing/release-template.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --release-hook releaseScalaLib
#
#    # releases version v0.1.0 using releaseScalaLib as hook and
#    # searches for additional occurrences where the version should be replaced via the specified pattern in:
#    # - script files in ./src and ./scripts
#    # - ./README.md
#    "$dir_of_tegonal_scripts/releasing/release-template.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --release-hook releaseScalaLib \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"
#
#    # in case you want to provide your own release.sh and only want to do some pre-configuration
#    # (such as specify the release-hook) then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/release-template.sh"
#
#    # and then call the function with your pre-configuration settings:
#    # here we define the function which shall be used as release-hook after "$@", this way one cannot override it.
#    # put --release-hook before "$@" if you want to define only a default
#    releaseTemplates "$@" --release-hook releaseScalaLib
#
#    function releaseScalaLib_afterVersionUpdateHook() {
#    	# some additional version bumps (assuming version is in scope)
#    	local version
#    	perl -0777 -i -pe "s/.../$version/g" "build.sbt"
#    }
#
#    # and then call the function with your pre-configuration settings:
#    # here we define the function which shall be used as release-hook after "$@" this way one cannot override it.
#    # put --release-hook before "$@" if you want to define only a default
#    releaseTemplate "$@" --release-hook releaseScalaLib \
#    	--after-version-update-hook releaseScalaLib_afterVersionUpdateHook
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.13.0-SNAPSHOT'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/execute-if-defined.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/pre-release-checks-git.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-common-steps.sh"

function releaseTemplate() {
	source "$dir_of_tegonal_scripts/releasing/release-template.params.source.sh"
	source "$dir_of_tegonal_scripts/releasing/release-template.params-definition.source.sh"
	parseArguments releaseTemplateParams "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	source "$dir_of_tegonal_scripts/releasing/release-template.default-args.source.sh"
	exitIfNotAllArgumentsSet releaseTemplateParams "" "$TEGONAL_SCRIPTS_VERSION"

	exitIfArgIsNotFunction "$releaseHook" "$releaseHookParamPatternLong"
	exitIfArgIsNotFunction "$beforePrFn" "$beforePrFnParamPatternLong"
	exitIfArgIsNotFunction "$prepareNextDevCycleFn" "$prepareNextDevCycleFnParamPatternLong"

	preReleaseCheckGit \
		"$versionParamPatternLong" "$version" \
		"$branchParamPatternLong" "$branch" || return $?

	# make sure everything is up-to-date and works as it should
	"$beforePrFn" || return $?

	updateVersionCommonSteps \
		"$forReleaseParamPatternLong" true \
		"$versionParamPatternLong" "$version" \
		"$projectsRootDirParamPatternLong" "$projectsRootDir" \
		"$additionalPatternParamPatternLong" "$additionalPattern"

	executeIfFunctionNameDefined "$afterVersionUpdateHook" "$afterVersionUpdateHookParamPatternLong" \
		"$versionParamPatternLong" "$version" \
		"$projectsRootDirParamPatternLong" "$projectsRootDir" \
		"$additionalPatternParamPatternLong" "$additionalPattern"

	# run again since we made changes
	"$beforePrFn" || return $?

	"$releaseHook" || return $?

	if [[ $prepareOnly != true ]]; then
		git add "$projectsRootDir" || return $?
		git commit --edit -m "$version " || return $?
		local signsTags
		signsTags=$(git config --get tag.gpgSign || echo "false")
		if [[ $signsTags == true ]]; then
			git tag -a "$version" -m "$version" || die "could not create tag $version"
		else
			git tag "$version" || die "could not create tag $version"
		fi

		"$prepareNextDevCycleFn" \
			"$versionParamPatternLong" "$nextVersion" \
			"$additionalPatternParamPatternLong" "$additionalPattern" \
			"$projectsRootDirParamPatternLong" "$projectsRootDir" \
			"$beforePrFnParamPatternLong" "$beforePrFn" || die "could not prepare next dev cycle for version %s" "$nextVersion"

		git push origin "$version" || die "could not push tag %s to origin" "$version"
		git push || die "could not push commits"

		logSuccess "tag pushed and next dev cycle prepared and pushed"
	else
		printf "\033[1;33mskipping commit, creating tag and prepare-next-dev-cycle due to %s\033[0m\n" "$prepareOnlyParamPatternLong"
	fi
}

${__SOURCED__:+return}
releaseTemplate "$@"
