#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under European Union Public License 1.2
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.13.1
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
	# keep in sync with local -r further below (3 lines at the time of writing)
	exitIfVarsNotAlreadySetBySource devVersion additionalPattern
	# we help shellcheck to realise that these variables are initialised
	local -r devVersion="$devVersion" additionalPattern="$additionalPattern"

	# we only update the version in the header but not the GT_LATEST_VERSION on purpose -- i.e. we omit
	# -p on purpose (compared to additional-release-files-preparations.sh) -- because we don't want to set the SNAPSHOT
	# version since this would cause that we set the SNAPSHOT version next time we update files via gget
	updateVersionScripts -v "$devVersion" -d "$projectDir/.gt/remotes/tegonal-gh-commons/pull-hook.sh"
}
additionalPrepareNextSteps
