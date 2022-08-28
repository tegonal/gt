#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.14.0
#
#######  Description  #############
#
#  Functions to check declarations
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
#
#    function foo() {
#    	# shellcheck disable=SC2034
#    	local -rn arr=$1
#    	local -r fn=$2
#
#    	# resolves arr recursively via recursiveDeclareP and check that is a non-associative array
#    	checkArgIsArray arr 1       # same as exitIfArgIsNotArray if set -e has an effect on this line
#    	checkArgIsFunction "$fn" 2   # same as exitIfArgIsNotFunction if set -e has an effect on this line
#
#    	function describeTriple(){
#    		echo >&2 "array contains 3-tuples with names where the first value is the first-, the second the middle- and the third the lastname"
#    	}
#    	# check array with 3-tuples
#    	checkArgIsArrayWithTuples arr 3 "names" 1 describeTriple
#
#    	exitIfArgIsNotArray arr 1
#    	exitIfArgIsNotFunction "$fn" 2
#
#    		function describePair(){
#      		echo >&2 "array contains 2-tuples with names where the first value is the first-, and the second the lastname"
#      	}
#    	# check array with 2-tuples
#    	exitIfArgIsNotArrayWithTuples arr 2 "names" 1 describePair
#    }
#
#    if checkCommandExists "cat"; then
#    	echo "do whatever you want to do..."
#    fi
#
#    # give a hint how to install the command
#    checkCommandExists "git" "please install it via https://git-scm.com/downloads"
#
#    # same as checkCommandExists but exits instead of returning non-zero in case command does not exist
#    exitIfCommandDoesNotExist "git" "please install it via https://git-scm.com/downloads"
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
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"

function checkArgIsArray() {
	if ! (($# == 2)); then
		logError "Two arguments needs to be passed to checkArgIsArray, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: array      name of the array to check'
		echo >&2 '2: argNumber  what argument do we check (used in error message)'
		printStackTrace
		exit 9
	fi
	local -rn checkArgIsArray_arr=$1
	local -r argNumber=$2
	shift 2 || die "could not shift by 2"

	reg='^declare -a.*'
	local arrayDefinition
	# we are not failing (with || die...) on this line as the if will fail afterwards
	arrayDefinition="$(recursiveDeclareP checkArgIsArray_arr)"
	if ! [[ $arrayDefinition =~ $reg ]]; then
		local funcName=${FUNCNAME[1]}
		if [[ $funcName == "exitIfArgIsNotArray" ]]; then
			funcName=${FUNCNAME[2]}
		fi
		traceAndReturnDying "the passed array \033[0;36m%s\033[0m is broken.\nThe %s argument to %s needs to be a non-associative array, given:\n%s" \
			"${!checkArgIsArray_arr}" "$argNumber" "$funcName" "$arrayDefinition"
	fi
}

function exitIfArgIsNotArray() {
	# we are aware of that || will disable set -e for checkArgIsArray
	# shellcheck disable=SC2310
	checkArgIsArray "$@" || exit $?
}

function checkArgIsArrayWithTuples() {
	if ! (($# == 5)); then
		logError "Five arguments needs to be passed to checkArgIsArrayWithTuples, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: array            name of the array to check'
		echo >&2 '2: tupleNum         the number of values of each tuple'
		echo >&2 '3: tupleRepresents  what does the tuple represent (used in error message)'
		echo >&2 '4: argNumber        what argument do we check (used in error message)'
		echo >&2 '5: describeTupleFn  function which describes how the tuples are built up'
		printStackTrace
		exit 9
	fi

	local -rn checkArgIsArrayWithTuples_paramArr=$1
	local -r tupleNum=$2
	local -r tupleRepresents=$3
	local -r argNumber=$4
	local -r describeTupleFn=$5
	shift 5 || die "could not shift by 5"

	local -r arrLength=${#checkArgIsArrayWithTuples_paramArr[@]}

	exitIfArgIsNotFunction "$describeTupleFn" "$argNumber"

	local funcName=${FUNCNAME[1]}
	if [[ $funcName == "exitIfArgIsNotArrayWithTuples" ]]; then
		funcName=${FUNCNAME[2]}
	fi

	local arrayDefinition
	arrayDefinition=$(recursiveDeclareP checkArgIsArrayWithTuples_paramArr) || die "could not get array definition of %s" "${!checkArgIsArrayWithTuples_paramArr}"
	reg='declare -a.*'
	if ! [[ "$arrayDefinition" =~ $reg ]]; then
		logError "the passed array \033[0;36m%s\033[0m is broken" "${!checkArgIsArrayWithTuples_paramArr}"
		printf >&2 "The %s argument to %s needs to be a non-associative array containing %s, given:\n" "$argNumber" "$funcName" "$tupleRepresents"
		echo >&2 "$arrayDefinition"
		echo >&2 ""
		"$describeTupleFn"
		printStackTrace
		exit 9
	fi

	if ((arrLength == 0)); then
		logError "the passed array \033[0;36m%s\033[0m is broken, length was 0\033[0m" "${!checkArgIsArrayWithTuples_paramArr}"
		printf >&2 "The %s argument to %s needs to be a non-empty array containing %s, given:\n" "$argNumber" "$funcName" "$tupleRepresents"
		"$describeTupleFn"
		printStackTrace
		exit 9
	fi

	if ! ((arrLength % tupleNum == 0)); then
		logError "the passed array \033[0;36m%s\033[0m is broken" "${!checkArgIsArrayWithTuples_paramArr}"
		printf >&2 "The %s argument to %s needs to be an array with %s-tuples containing %s, given:\n" "$argNumber" "$funcName" "$tupleNum" "$tupleRepresents"
		"$describeTupleFn"
		echo >&2 ""
		echo >&2 "given:"
		echo >&2 "$arrayDefinition"
		echo >&2 ""
		echo >&2 "following how we split this:"

		local -i i j
		for ((i = 0; i < arrLength; i += tupleNum)); do
			local -r length=$((i + tupleNum - 1 < arrLength ? i + tupleNum : arrLength))
			if ((i + tupleNum - 1 >= arrLength)); then
				printf >&2 "\033[1;33mleftovers:\033[0m\n"
			fi
			for ((j = i; j < length; ++j)); do
				printf >&2 '"%s" ' "${checkArgIsArrayWithTuples_paramArr[$j]}"
			done
			printf >&2 "\n"
		done
		printStackTrace
		exit 9
	fi
}

function exitIfArgIsNotArrayWithTuples() {
	# we are aware of that || will disable set -e for checkArgIsArrayWithTuples
	# shellcheck disable=SC2310
	checkArgIsArrayWithTuples "$@" || exit $?
}

function checkArgIsFunction() {
	local name argNumber
	# params is required for parseFnArgs thus:
	# shellcheck disable=SC2034
	local -ra params=(name argNumber)
	parseFnArgs params "$@"

	if ! declare -F "$name" >/dev/null; then
		local declareP
		declareP=$(declare -p "$name" || echo "failure, is not a variable")
		local funcName=${FUNCNAME[1]}
		if [[ $funcName == "exitIfArgIsNotFunction" ]]; then
			funcName=${FUNCNAME[2]}
		fi
		traceAndReturnDying "the %s argument to %s needs to be a function/command, %s isn't one\nMaybe it is a variable storing the name of a function?\nFollowing the output of: declare -p %s\n%s" \
			"$argNumber" "$funcName" "$name" "$name" "$declareP"
	fi
}

function exitIfArgIsNotFunction() {
	# we are aware of that || will disable set -e for checkArgIsFunction
	# shellcheck disable=SC2310
	checkArgIsFunction "$@" || exit $?
}

function checkCommandExists() {
	if ! (($# == 1 || $# == 2)); then
		traceAndDie "you need to pass the name of the command to check to checkCommandExists and optionally an additional hint (e.g. install via...)"
	fi
	local -r name=$1
	local file
	file=$(command -v "$name") || returnDying "%s is not installed (or not in PATH) %s" "$name" "${2:-""}" || return $?
	if ! [[ -x $file ]]; then
		returnDying "%s is on the system at %s (according to command) but is not executable. Consider to execute:\nsudo chmod +x %s" "$name" "$file" "$file" || return $?
	fi
}

function exitIfCommandDoesNotExist() {
	# we are aware of that || will disable set -e for checkCommandExists
	# shellcheck disable=SC2310
	checkCommandExists "$@" || exit $?
}
