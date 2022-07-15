#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.7.0
#
#######  Description  #############
#
#  Utility functions wrapping printf and prefixing the message with a coloured INFO, WARNING or ERROR.
#  logError writes to stderr and logWarning and logInfo to stdout
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -eu
#    declare dir_of_tegonal_scripts
#    # Assuming tegonal's scripts are in the same directory as your script
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#    source "$dir_of_tegonal_scripts/utility/log.sh"
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
###################################
set -eu

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
