#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.5.1
#######  Description  #############
#
#  Utility functions wrapping printf and prefixing the message with a coloured INFO, WARNING or ERROR.
#  logError writes to stderr and logWarning and logInfo to stdout
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
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
shopt -s inherit_errexit
unset CDPATH

function logInfo() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	logInfoWithoutNewline "$msg\n" "$@"
}
function logInfoWithoutNewline() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	printf "\033[0;34mINFO\033[0m: $msg" "$@"
}

function logWarning() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	logWarningWithoutNewline "$msg\n" "$@"
}
function logWarningWithoutNewline() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	printf "\033[0;93mWARNING\033[0m: $msg" "$@"
}

function logError() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	logErrorWithoutNewline "$msg\n" "$@"
}
function logErrorWithoutNewline() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	printf >&2 "\033[0;31mERROR\033[0m: $msg" "$@"
}

function logSuccess() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	logSuccessWithoutNewline "$msg\n" "$@"
}
function logSuccessWithoutNewline() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	printf "\033[0;32mSUCCESS\033[0m: $msg" "$@"
}

function die() {
	logError "$@"
	exit 1
}

# note that this function has not the effect of a return if set -e is not in place
# (either not set or function call tree passed an if while until or was on the left side of an || &&)
# in such a case you either need to make sure that your returnDying is the last call in your function
# or you need to add `|| return $?`.
function returnDying() {
	logError "$@"
	return 1
}

function printStackTrace() {
	echo >&2 ""
	echo >&2 "Stacktrace:"
	local -i frame=${1:-0}
	local line sub file
	# we want that the while loop ends in case caller "$frame" returns non-zero, thus
	# shellcheck disable=SC2312
	while read -r line sub file < <(caller "$frame"); do
		local path
		path=$(realpath "$file" || echo "$file")
		printf >&2 '%20s @ %s:%s:1\n' "$sub" "$path" "$line"
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
