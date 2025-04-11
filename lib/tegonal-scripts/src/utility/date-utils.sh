#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v4.7.0
#
#######  Description  #############
#
#  utility functions for dealing with date(-time) and unix timestamps
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo "please update to bash 5, see errors above"; exit 1; }
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
#    # outputs a timestamp in ms
#    startTimestampInMs="$(timestampInMs)"
#
#    formatMsToSeconds 12 		# outputs 0.012
#    formatMsToSeconds 1234  # outputs 1.234
#    formatMsToSeconds -123  # outputs -0.123
#    # note that formatMsToSeconds does not check if you pass a number
#
#    # outputs the time passed since the given timestamp in ms formatted as seconds
#    elapsedSecondsBasedOnTimestampInMs "$startTimestampInMs"
#
###################################
set -euo pipefail
shopt -s inherit_errexit || {
	echo "please update to bash 5, see errors above"
	exit 1
}
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

function timestampInMs() {
	local timestamp
	timestamp="$(date +%s%3N 2>/dev/null || "3N")"
	if [[ $timestamp =~ 3N$ ]]; then
		# N modifier is not supported. Most likely date is not GNU date but BSD date
		if command -v gdate; then
			gdate +%s%3N 2>/dev/null
		elif command -v perl >/dev/null; then
			perl -MTime::HiRes=time -E 'printf("%.0f\n", time * 1000)' 2>/dev/null
		else
			# we give up and get a timestamp in seconds instead and append 000
			local timestampInSeconds
			timestampInSeconds="$(date +%s)"
			echo "${timestampInSeconds}000"
		fi
	else
		echo "$timestamp"
	fi
}

function elapsedSecondsBasedOnTimestampInMs() {
	local startTimestampInMs
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(startTimestampInMs)
	parseFnArgs params "$@"

	if ((${#startTimestampInMs} != 13)); then
		die "looks like the given start timestamp was not in milliseconds, should have length 13 but was %s -- consider using timestampInMs -- following the given startTimestampInMs: %s" " ${#startTimestampInMs}" "$startTimestampInMs"
	fi

	local endTimestampInMs
	endTimestampInMs="$(timestampInMs)"
	elapsedInMs="$((endTimestampInMs - startTimestampInMs))"
	formatMsToSeconds "$elapsedInMs"
}

function formatMsToSeconds() {
	local millis
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(millis)
	parseFnArgs params "$@"

	local sign
	if [[ $millis =~ ^- ]]; then
		sign="-"
		millis="${millis#-}"
	else
		sign=""
	fi

	local -r length=${#millis}

	if ((length <= 3)); then
		printf "%s0.%03d\n" "$sign" "$millis"
	else
		local intPart="${millis:0:-3}"
		local fracPart="${millis: -3}"
		echo "${sign}${intPart}${fracPart:+".$fracPart"}"
	fi
}
