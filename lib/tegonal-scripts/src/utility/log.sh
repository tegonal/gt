#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.9.0
#
#######  Description  #############
#
#  Utility functions wrapping printf and prefixing the message with a coloured INFO, WARNING or ERROR.
#  logError writes to stderr and logWarning and logInfo to stdout
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
#
#    logInfo "hello %s" "world"
#    # INFO: hello world
#
#    logInfo "line %s" 1 2 3
#    # INFO: line 1
#    # INFO: line 2
#    # INFO: line 3
#
#    logWarning "oho..."
#    # WARNING: oho...
#
#    logError "illegal state..."
#    # ERROR: illegal state...
#
#    seconds=54
#    logSuccess "import finished in %s seconds" "$seconds"
#    # SUCCESS: import finished in 54 seconds
#
#    die "fatal error, shutting down"
#    # ERROR: fatal error, shutting down
#    # exit 1
#
#    returnDying "fatal error, shutting down"
#    # ERROR: fatal error, shutting down
#    # return 1
#
#    # in case you don't want a newline at the end of the message, then use one of
#    logInfoWithoutNewline "hello"
#    # INFO: hello%
#    logWarningWithoutNewline "be careful"
#    logErrorWithoutNewline "oho"
#    logSuccessWithoutNewline "yay"
#
#    traceAndDie "fatal error, shutting down"
#    # ERROR: fatal error, shutting down
#    #
#    # Stacktrace:
#    #    foo @ /opt/foo.sh:32:1
#    #    bar @ /opt/bar.sh:10:1
#    #    ...
#    # exit 1
#
#    traceAndReturnDying "fatal error, shutting down"
#    # ERROR: fatal error, shutting down
#    #
#    # Stacktrace:
#    #    foo @ /opt/foo.sh:32:1
#    #    bar @ /opt/bar.sh:10:1
#    #    ...
#    # return 1
#
#    printStackTrace
#    # Stacktrace:
#    #    foo @ /opt/foo.sh:32:1
#    #    bar @ /opt/bar.sh:10:1
#    #   main @ /opt/main.sh:4:1
#
###################################
set -euo pipefail

function logInfo() {
	local msg=$1
	shift
	logInfoWithoutNewline "$msg\n" "$@"
}
function logInfoWithoutNewline() {
	local msg=$1
	shift
	printf "\033[0;34mINFO\033[0m: $msg" "$@"
}

function logWarning() {
	local msg=$1
	shift
	logWarningWithoutNewline "$msg\n" "$@"
}
function logWarningWithoutNewline() {
	local msg=$1
	shift
	printf "\033[0;93mWARNING\033[0m: $msg" "$@"
}

function logError() {
	local msg=$1
	shift
	logErrorWithoutNewline "$msg\n" "$@"
}
function logErrorWithoutNewline() {
	local msg=$1
	shift
	printf >&2 "\033[0;31mERROR\033[0m: $msg" "$@"
}

function logSuccess() {
	local msg=$1
	shift
	logSuccessWithoutNewline "$msg\n" "$@"
}
function logSuccessWithoutNewline() {
	local msg=$1
	shift
	printf "\033[0;32mSUCCESS\033[0m: $msg" "$@"
}

function die() {
	logError "$@"
	exit 1
}
function returnDying() {
	logError "$@"
	return 1
}

function printStackTrace() {
	echo >&2 ""
	echo >&2 "Stacktrace:"
	local -i frame=${1:-1}
	while read -r line sub file < <(caller "$frame"); do
		printf >&2 '%20s @ %s:%s:1\n' "$sub" "$(realpath "$file" || echo "$file")" "$line"
		((++frame))
		if ((frame > 10)); then
			echo >&2 " ..."
			break
		fi
	done
}

function traceAndDie() {
	logError "$@"
	printStackTrace 1
	exit 1
}

function traceAndReturnDying() {
	logError "$@"
	printStackTrace 1
	return 1
}
