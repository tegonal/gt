#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v4.4.3
#
#######  Description  #############
#
#  utility functions for dealing with date(-time) and unix timestamps
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#
#    projectDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
#
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/date-utils.sh"
#
#    # converts the unix timestamp to a date with time in format Y-m-dTH:M:S
#    timestampToDateTime 1662981524 # outputs 2022-09-12T13:18:44
#
#    # converts the unix timestamp to a date in format Y-m-d
#    timestampToDate 1662981524 # outputs 2022-09-12
#
#    # converts the unix timestamp to a date in format as defined by LC_TIME
#    # (usually as defined by the user in the system settings)
#    timestampToDateInUserFormat 1662981524 # outputs 12.09.2022 for ch_DE
#
#    dateToTimestamp "2024-03-01" # outputs 1709247600
#    dateToTimestamp "2022-09-12T13:18:44" # outputs 1662981524
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function timestampToDateTime() {
	local timestamp
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(timestamp)
	parseFnArgs params "$@"
	date -d "@$timestamp" +"%Y-%m-%dT%H:%M:%S"
}

function timestampToDate() {
	local timestamp
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(timestamp)
	parseFnArgs params "$@"
	date -d "@$timestamp" +"%Y-%m-%d"
}

function timestampToDateInUserFormat() {
	local timestamp
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(timestamp)
	parseFnArgs params "$@"
	date -d "@$timestamp" +"%x"
}

function dateToTimestamp() {
	local dateAsString
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(dateAsString)
	parseFnArgs params "$@"
	date -d "$dateAsString" +%s
}
