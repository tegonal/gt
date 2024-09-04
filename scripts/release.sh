#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.19.0-SNAPSHOT
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
GT_VERSION="v0.19.0-SNAPSHOT"

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	readonly projectDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/releasing/release-files.sh"
sourceOnce "$scriptsDir/before-pr.sh"
sourceOnce "$scriptsDir/prepare-next-dev-cycle.sh"
sourceOnce "$scriptsDir/update-version-in-non-sh-files.sh"

function release() {
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || die "could not source common-constants.source.sh"

	local version
	# shellcheck disable=SC2034   # they seem unused but are necessary in order that parseArguments doesn't create global readonly vars
	local key branch nextVersion prepareOnly
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" "$versionParamDocu"
		key "$keyParamPattern" "$keyParamDocu"
		branch "$branchParamPattern" "$branchParamDocu"
		nextVersion "$nextVersionParamPattern" "$nextVersionParamDocu"
		prepareOnly "$prepareOnlyParamPattern" "$prepareOnlyParamDocu"
	)
	parseArguments params "" "$GT_VERSION" "$@"
	# we don't check if all args are set (and neither set default values) as we currently don't use
	# any param in here but just delegate to releaseFiles.

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
		local version projectsRootDir additionalPattern
		parseArguments afterVersionHookParams "" "$GT_VERSION" "$@"

		updateVersionInNonShFiles -v "$version" --project-dir "$projectsRootDir" --pattern "$additionalPattern"

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
	releaseFiles \
		--project-dir "$projectDir" \
		--pattern "$additionalPattern" \
		"$@" \
		--sign-fn findFilesToRelease \
		--after-version-update-hook release_afterVersionHook
}

${__SOURCED__:+return}
release "$@"
