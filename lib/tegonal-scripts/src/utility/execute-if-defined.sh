#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.1
#######  Description  #############
#
#  Utility functions wrapping printf and prefixing the message with a coloured INFO, WARNING or ERROR.
#  logError writes to stderr and logWarning and logInfo to stdout
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    MY_LIB_VERSION="v1.1.0"
#
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/execute-if-defined.sh"
#
#    function foo() {
#    	executeIfFunctionNameDefined "$1" "1" "args" "passed" "to" "function"
#    }
#
#    function bar() {
#    	local findFn
#    	# shellcheck disable=SC2034   # is passed by name to parseArguments
#    	declare params=(
#    		findFn '--find-fn' ''
#    	)
#    	parseArguments params "" "$MY_LIB_VERSION" "$@" || return $?
#
#    	executeIfFunctionNameDefined "$findFn" "--find-fn" "args" "passed" "to" "function"
#    }
#
#    # calls myFun and passing the following as arguments: "args" "passed" "to" "function"
#    executeIfFunctionNameDefined "myFun" "-" "args" "passed" "to" "function"
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function executeIfFunctionNameDefined() {
	if (($# < 2)); then
		logError "At least two arguments need to be passed to executeIfFunctionNameDefined, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
			echo >&2 '1: functionName     the function which shall be executed if defined'
			echo >&2 '2: argNumberOrName  via which arg (number or name) was the function name defined (used in the error messages)'
			echo >&2 '3... args...        arguments passed to the function'
			printStackTrace
			exit 9
	fi
	local functionName=$1
	local argNumberOrName=$2
	shift 2 || traceAndDie "could not shift by 2"
	if [[ -n $functionName ]]; then
		exitIfArgIsNotFunction "$functionName" "$argNumberOrName"
		logInfo "arg %s defined (%s), going to call it" "$argNumberOrName" "$functionName"
		"$functionName" "$@"
	fi
}
