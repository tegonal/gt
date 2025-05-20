#!/usr/bin/env bash
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
#  Utility functions for argument parser like function such as parse-args and parse-fn-args
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    MY_LIBRARY_VERSION="v1.0.3"
#
#    if ! [[ -v dir_of_tegonal_scripts ]]; then
#    	# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#    fi
#    sourceOnce "$dir_of_tegonal_scripts/utility/parse-utils.sh"
#
#    function myParseFunction() {
#    	while (($# > 0)); do
#    		if [[ $1 == "--version" ]]; then
#    			shift 1 || traceAndDie "could not shift by 1"
#    			printVersion "$MY_LIBRARY_VERSION"
#    		fi
#    		#...
#    	done
#    }
#
#    function myVersionPrinter() {
#    	# 3 defines that printVersion shall skip 3 stack frames to deduce the name of the script
#    	# makes only sense if we already know that this method is called indirectly
#    	printVersion "$MY_LIBRARY_VERSION" 3
#    }
#
#######	Limitations	#############
#
#	1. Does not support repeating arguments (last wins and overrides previous definitions)
#	2. Supports named arguments only (e.g. not possible to pass positional arguments after the named arguments)
#
#	=> take a look at https://github.com/ko1nksm/getoptions if you need something more powerful
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

function printVersion() {
	if (($# != 1)) && (($# != 2)); then
		logError "Either one or two arguments need to be passed to printVersion, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: version   		the version which shall be shown if one uses --version'
		echo >&2 '2: stackFrame   number of frames to drop to determine the source of the call -- default 3'
		printStackTrace
		exit 9
	fi
	local version=$1
	local stackFrame=${2:-3}
	local name
	name=$(basename "${BASH_SOURCE[stackFrame]:-${BASH_SOURCE[((stackFrame - 1))]}}" || echo "<unknown>")
	logInfo "Version of %s is:\n%s" "$name" "$version"
}

function assignToVariableInOuterScope() {
	if (($# != 2)); then
		logError "Exactly two arguments need to be passed to assignToOuterScopeVariable, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: variableName   the name of the variable in the outer scope to which the given value shall be assigned'
		echo >&2 '2: value   				the value which shall be assigned to the variable'
		printStackTrace
		exit 9
	fi
	exitIfVariablesNotDeclared "$1"
	# that's where the black magic happens, we are assigning to global (not local to this function) variables here
	printf -v "$1" "%s" "$2" || traceAndDie "could not assign value to %s" "$1"
}
