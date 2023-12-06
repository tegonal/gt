#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under European Union Public License 1.2
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.14.0
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
	if ! wget -q -O- "https://api.github.com/repos/tegonal/gt/actions/workflows/installation.yml/runs?per_page=1&status=completed&branch=main" | grep '"conclusion": "success"' > /dev/null; then
		die "installation workflow failed, you should not release ;-)"
	fi

	function findFilesToRelease() {
		find "$projectDir/src" \
		"$projectDir/install.sh" "$projectDir/install.doc.sh" \
		"$projectDir/.github/workflows/gt-update.yml" \
			\( -not -name "*.doc.sh" -o -name "install.doc.sh" \) \
			"$@"
	}

# similar as in prepare-next-dev-cycle.sh, you might need to update it there as well if you change something here
	local -r additionalPattern="(GT_(?:LATEST_)?VERSION=['\"])[^'\"]+(['\"])"
	releaseFiles --project-dir "$projectDir" -p "$additionalPattern" --sign-fn findFilesToRelease "$@"
}

${__SOURCED__:+return}
release "$@"
