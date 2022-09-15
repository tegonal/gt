#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/github-commons
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Creative Commons Zero v1.0 Universal
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.7.0-SNAPSHOT
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
	dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function additionalPrepareNextSteps() {
	# keep in sync with local -r
	exitIfVarsNotAlreadySetBySource devVersion additionalPattern
	# we help shellcheck to realise that these variables are initialised
	local -r devVersion="$devVersion" additionalPattern="$additionalPattern"

	local -ra additionalScripts=(
  		"$projectDir/.gget/remotes/tegonal-gh-commons/pull-hook.sh"
  	)
  	for script in "${additionalScripts[@]}"; do
  		updateVersionScripts -v "$devVersion" -p "$additionalPattern" -d "$script"
  	done
}
additionalPrepareNextSteps
