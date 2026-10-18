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
sourceOnce "$dir_of_tegonal_scripts/releasing/release-files-template.sh"
sourceOnce "$scriptsDir/before-pr.sh"
sourceOnce "$scriptsDir/prepare-next-dev-cycle.sh"
sourceOnce "$scriptsDir/update-version-in-non-sh-files.sh"

function release() {
	source "$dir_of_tegonal_scripts/releasing/params/release-files.params.source.sh" || traceAndDie "could not source release-files.params.source.sh"
	source "$dir_of_tegonal_scripts/releasing/params/release-files.params-definition.source.sh" || traceAndDie "could not source release-files.params-definition.source.sh"
	parseArguments releaseFilesParams "" "$GT_VERSION" "$@" || return $?
	source "$dir_of_tegonal_scripts/releasing/params/release-files.default-args.source.sh" || die "could not source release-files.default-args.source.sh"
	exitIfNotAllArgumentsSet releaseFilesParams "" "$GT_VERSION"

	local -a releaseFilesTemplateArgs
	addLocalVarMatchingParamNamesToArgs releaseFilesTemplateParams releaseFilesTemplateArgs

	if ! wget -q -O- "https://api.github.com/repos/tegonal/gt/actions/workflows/installation.yml/runs?per_page=1&status=completed&branch=main" | grep '"conclusion": "success"' >/dev/null; then
		die "installation workflow failed, you should not release ;-)"
	fi

	function findFilesToRelease() {
		find "$projectDir/src" \
			"$projectDir/install.sh" "$projectDir/install.doc.sh" \
			"$projectDir/.github/workflows/gt-update.yml" \
			\( -not -name "*.doc.sh" -o -name "install.doc.sh" \) \
			"$@"
	}

	function release_afterVersionHook() {
		source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params.source.sh" || traceAndDie "could not source after-version-update-hook.params.source.sh"
		source "$dir_of_tegonal_scripts/releasing/params/after-version-update-hook.params-definition.source.sh" || traceAndDie "could not source after-version-update-hook.params-definition.source.sh"
		parseArguments afterVersionHookParams "" "$GT_VERSION" "$@" || return $?
		exitIfNotAllArgumentsSet afterVersionHookParams "" "$GT_VERSION"

		local -a updateVersionInNonShFilesArgs
		addLocalVarMatchingParamNamesToArgs afterVersionHookParams updateVersionInNonShFilesArgs

		updateVersionInNonShFiles "${updateVersionInNonShFilesArgs[@]}"

		# same as in pull-hook.sh
		local -r githubUrl="https://github.com/tegonal/gt"
		replaceTagInPullRequestTemplate "$projectsRootDir/.github/PULL_REQUEST_TEMPLATE.md" "$githubUrl" "$version" || die "could not fill the placeholders in PULL_REQUEST_TEMPLATE.md"

		perl -0777 -i \
			-pe "s@(tegonal/gt/)[^/]+(/install.sh)@\${1}$version\${2}@g;" \
			"$projectDir/install.doc.sh" || returnDying "error during replacing the version in install.doc.sh" || return $?

		# update workflow which checks self-update, now that we release a new version,
		# we can add the current latest version (before the release is published) to the workflow
		declare latestTag
		latestTag=$(latestRemoteTag)
		perl -0777 -i \
			-pe "s@(installOld:[\S\s]+strategy:[\n\s]+matrix:[\n\s]+tag:\s+\[[^\]]+)\]@\${1}, $latestTag\]@g;" \
			"$projectDir/.github/workflows/installation.yml" || returnDying "error during placing the latest release into installation.yml installOld -> matrix -> tag" || return $?
	}

	# similar as in prepare-next-dev-cycle.sh, you might need to update it there as well if you change something here
	local -r additionalPattern="(GT_(?:LATEST_)?VERSION=['\"])[^'\"]+(['\"])"

	releaseFilesTemplate \
		"$projectsRootDirParamPatternLong" "$projectDir" \
		"$additionalPatternParamPatternLong" "$additionalPattern" \
		"${releaseFilesTemplateArgs[@]}" \
		"$findForSigningParamPatternLong" findFilesToRelease \
		"$afterVersionUpdateHookParamPatternLong" release_afterVersionHook
}

${__SOURCED__:+return}
release "$@"
