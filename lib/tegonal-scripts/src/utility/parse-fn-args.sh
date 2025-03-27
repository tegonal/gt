#!/usr/bin/env bash
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
# Intended to parse positional function parameters including assignment and check if there are enough arguments
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#
#    if ! [[ -v dir_of_tegonal_scripts ]]; then
#    	# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#    fi
#    sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"
#
#    function myFunction() {
#    	# declare the variable you want to use and repeat in `declare params`
#    	local command dir
#
#    	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
#    	local -ra params=(command dir)
#    	parseFnArgs params "$@"
#
#    	# pass your variables storing the arguments to other scripts
#    	echo "command: $command, dir: $dir"
#    }
#
#    function myFunctionWithVarargs() {
#
#    	# in case you want to use a vararg parameter as last parameter then name your last parameter for `params` varargs:
#    	local command dir varargs
#    	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
#    	local -ra params=(command dir varargs)
#    	parseFnArgs params "$@"
#
#    	# use varargs in another script
#    	echo "command: $command, dir: $dir, varargs: ${varargs*}"
#    }
#
#######	Limitations	#############
#
#	1. Does not support named arguments (see parse-args.sh if you want named arguments for your function)
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function parseFnArgs() {
	if (($# < 2)); then
		logError "At least two arguments need to be passed to parseFnArgs, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: params     the name of an array which contains the parameter names'
		echo >&2 '2... args...  the arguments as such, typically "$@"'
		printStackTrace
		exit 9
	fi

	# using unconventional naming in order to avoid name clashes with the variables we will initialise further below
	local -rn parseFnArgs_paramArr1=$1
	shift 1 || traceAndDie "could not shift by 1"

	exitIfArgIsNotArray parseFnArgs_paramArr1 1

	local parseFnArgs_withVarArgs
	if [[ ${parseFnArgs_paramArr1[$((${#parseFnArgs_paramArr1[@]} - 1))]} == "varargs" ]]; then
		parseFnArgs_withVarArgs=true
	else
		parseFnArgs_withVarArgs=false
	fi

	local parseFnArgs_minExpected
	if [[ $parseFnArgs_withVarArgs == false ]]; then
		parseFnArgs_minExpected="${#parseFnArgs_paramArr1[@]}"
	else
		parseFnArgs_minExpected="$((${#parseFnArgs_paramArr1[@]} - 1))"
	fi
	local -r parseFnArgs_minExpected
	local -i parseFnArgs_i

	if (($# < parseFnArgs_minExpected)); then
		logError "Not enough arguments supplied to \033[0m\033[0;36m%s\033[0m\nExpected %s, given %s\nFollowing a listing of the expected arguments (red means missing):" \
			"${FUNCNAME[1]}" "${#parseFnArgs_paramArr1[@]}" "$#"

		for ((parseFnArgs_i = 0; parseFnArgs_i < parseFnArgs_minExpected; ++parseFnArgs_i)); do
			local parseFnArgs_name=${parseFnArgs_paramArr1[parseFnArgs_i]}
			if ((parseFnArgs_i < $#)); then
				printf >&2 "\033[0;32m"
			else
				printf >&2 "\033[0;31m"
			fi
			printf >&2 "%2s: %s\033[0m\n" "$((parseFnArgs_i + 1))" "$parseFnArgs_name"
		done
		if [[ $parseFnArgs_withVarArgs == true ]]; then
			printf >&2 "%2s: %s\n" "$((parseFnArgs_i + 1))" "varargs"
		fi
		printStackTrace
		exit 9
	fi

	if [[ $parseFnArgs_withVarArgs == false ]] && (($# != ${#parseFnArgs_paramArr1[@]})); then
		logError "more arguments supplied to \033[0m\033[0;36m%s\033[0m than expected\nExpected %s, given %s" \
			"${FUNCNAME[1]}" "${#parseFnArgs_paramArr1[@]}" "$#"
		echo >&2 "in case you wanted your last parameter to be a vararg parameter, then use 'varargs' as last variable name in your array containing the parameter names."
		echo >&2 "Following a listing of the expected arguments:"
		for ((parseFnArgs_i = 0; parseFnArgs_i < parseFnArgs_minExpected; ++parseFnArgs_i)); do
			local parseFnArgs_name=${parseFnArgs_paramArr1[parseFnArgs_i]}
			printf >&2 "%2s: %s\n" "$((parseFnArgs_i + 1))" "$parseFnArgs_name"
		done
		printStackTrace
		exit 9
	fi

	exitIfVariablesNotDeclared "${parseFnArgs_paramArr1[@]}"

	for ((parseFnArgs_i = 0; parseFnArgs_i < parseFnArgs_minExpected; ++parseFnArgs_i)); do
		local parseFnArgs_name=${parseFnArgs_paramArr1[parseFnArgs_i]}
		# assign arguments to specified variables
		printf -v "$parseFnArgs_name" "%s" "$1" || traceAndDie "could not assign value to $parseFnArgs_name"
		local -r "$parseFnArgs_name"
		shift 1 || traceAndDie "could not shift by 1"
	done

	# assign rest to varargs if used
	if [[ $parseFnArgs_withVarArgs == true ]]; then
		# shellcheck disable=SC2034   # varargs is defined in outer scope and will be used there, thus ok
		varargs=("$@") || traceAndDie "could not assign the rest of arguments to varargs"
	fi
}
