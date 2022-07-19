#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.2.0-SNAPSHOT
#
###################################
set -euo pipefail

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	declare -r scriptsDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$scriptsDir/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/releasing/release-files.sh"

function release() {
	function findScripts() {
		find "$scriptsDir/../src" -name "*.sh" -not -name "*.doc.sh" "$@"
	}

	# same as in prepare-next-dev-cycle.sh, update there as well
	local -r additionalPattern="(GGET_VERSION=['\"])[^'\"]+(['\"])"

	releaseFiles --project-dir "$(realpath "$scriptsDir/..")" -p "$additionalPattern" --sign-fn findScripts "$@"
}

${__SOURCED__:+return}
release "$@"
