#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.6.0
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	readonly projectDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$scriptsDir/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/releasing/release-files.sh"

function release() {
	function findFilesToRelease() {
		find "$projectDir/src" \
		"$projectDir/install.sh" "$projectDir/install.doc.sh" \
		"$projectDir/.github/workflows/gget-update.yml" \
			\( -not -name "*.doc.sh" -o -name "install.doc.sh" \) \
			"$@"
	}

	local -r additionalPattern="(GGET_(?:LATEST_)?VERSION=['\"])[^'\"]+(['\"])"
	releaseFiles --project-dir "$projectDir" -p "$additionalPattern" --sign-fn findFilesToRelease "$@"
}

${__SOURCED__:+return}
release "$@"
