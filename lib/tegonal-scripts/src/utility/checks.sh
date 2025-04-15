#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.0
#######  Description  #############
#
#  Functions to check declarations
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
#
#    function foo() {
#    	# shellcheck disable=SC2034   # is passed by name to checkArgIsArray
#    	local -rn arr=$1
#    	local -r fn=$2
#    	local -r bool=$3
#    	local -r version=$4
#
#    	# resolves arr recursively via recursiveDeclareP and check that is a non-associative array
#    	checkArgIsArray arr 1        		# same as exitIfArgIsNotArray if set -e has an effect on this line
#    	checkArgIsFunction "$fn" 2   		# same as exitIfArgIsNotFunction if set -e has an effect on this line
#    	checkArgIsBoolean "$bool" 3   	# same as exitIfArgIsNotBoolean if set -e has an effect on this line
#    	checkArgIsVersion "$version" 4  # same as exitIfArgIsNotVersion if set -e has an effect on this line
#
#    	# shellcheck disable=SC2317   # is passed by name to checkArgIsArrayWithTuples
#    	function describeTriple() {
#    		echo >&2 "array contains 3-tuples with names where the first value is the first-, the second the middle- and the third the lastname"
#    	}
#    	# check array with 3-tuples
#    	checkArgIsArrayWithTuples arr 3 "names" 1 describeTriple
#
#    	exitIfArgIsNotArray arr 1
#    	exitIfArgIsNotArrayOrIsEmpty arr 1
#    	exitIfArgIsNotArrayOrIsNonEmpty arr 1
#    	exitIfArgIsNotFunction "$fn" 2
#    	exitIfArgIsNotBoolean "$bool" 3
#    	exitIfArgIsNotVersion "$version" 4
#
#    	# shellcheck disable=SC2317   # is passed by name to exitIfArgIsNotArrayWithTuples
#    	function describePair() {
#    		echo >&2 "array contains 2-tuples with names where the first value is the first-, and the second the last name"
#    	}
#    	# check array with 2-tuples
#    	exitIfArgIsNotArrayWithTuples arr 2 "names" 1 describePair
#
#    	# returns 0 if the array was initialised (i.e. a value assigned) and non-0 otherwise
#    	checkIsInitialisedArray arr
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
#    # meant to be used in a file which is sourced where a contract exists between the file which `source`s and the sourced file
#    exitIfVarsNotAlreadySetBySource myVar1 var2 var3
#
#    declare myVar4
#    exitIfVariablesNotDeclared myVar4 myVar5 # would exit because myVar5 is not set
#    echo "myVar4 $myVar4"
#
#    declare currentDir
#    currentDir=$(pwd)
#    checkPathNamedIsInsideOf "$myVar4" "source directory" "$currentDir" # same as exitIfPathNamedIsOutsideOf if set -e has an effect on this line
#    exitIfPathNamedIsOutsideOf "$myVar4/plugins.txt" "plugins" "$currentDir"
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"

function checkArgIsArray() {
	if (($# != 2)); then
		logError "Two arguments need to be passed to checkArgIsArray, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: array      		  name of the array to check'
		echo >&2 '2: argNumberOrName  what argument do we check (used in error message)'
		printStackTrace
		exit 9
	fi
	local -rn checkArgIsArray_arr=$1
	local -r argNumberOrName=$2
	shift 2 || traceAndDie "could not shift by 2"

	reg='^declare -a.*'
	local arrayDefinition
	# we are not failing (with || die...) on this line as the if will fail afterwards
	arrayDefinition="$(recursiveDeclareP checkArgIsArray_arr)" || traceAndDie "could not get array definition of %s" "${!checkArgIsArray_arr}"
	if ! [[ $arrayDefinition =~ $reg ]]; then
		local funcName=${FUNCNAME[1]}
		if [[ $funcName == "exitIfArgIsNotArray" ]]; then
			funcName=${FUNCNAME[2]}
		fi
		if [[ $funcName == "exitIfArgIsNotArrayOrIsEmpty" ]] ||
			[[ $funcName == "exitIfArgIsNotArrayOrIsNonEmpty" ]]; then
			funcName=${FUNCNAME[3]}
		fi
		traceAndReturnDying "the passed array \033[0;36m%s\033[0m is broken.\nThe %s argument to %s needs to be a non-associative array, given:\n%s" \
			"${!checkArgIsArray_arr}" "$argNumberOrName" "$funcName" "$arrayDefinition"
	fi
}

function exitIfArgIsNotArray() {
	# shellcheck disable=SC2310		# we are aware of that || will disable set -e for checkArgIsArray
	checkArgIsArray "$@" || exit $?
}

function exitIfArgIsNotArrayOrIsEmpty() {
	exitIfArgIsNotArray "$@"
	local -rn exitIfArgIsNotArrayOrIsEmpty_arr=$1
	# shellcheck disable=SC2310		# we are aware of that if and ! will disable set -e for checkIsInitialisedArray
	if ! checkIsInitialisedArray exitIfArgIsNotArrayOrIsEmpty_arr; then
		traceAndDie "the passed argument \033[0;36m%s\033[0m is an uninitialised array" "${!exitIfArgIsNotArrayOrIsEmpty_arr}"
	elif [[ ${#exitIfArgIsNotArrayOrIsEmpty_arr[@]} -lt 1 ]]; then
		traceAndDie "the passed argument \033[0;36m%s\033[0m is an empty array" "${!exitIfArgIsNotArrayOrIsEmpty_arr}"
	fi
}

function exitIfArgIsNotArrayOrIsNonEmpty() {
	exitIfArgIsNotArray "$@"
	local -rn exitIfArgIsNotArrayOrIsNonEmpty_arr=$1
	# shellcheck disable=SC2310		# we are aware of that if and ! will disable set -e for checkIsInitialisedArray
	if checkIsInitialisedArray exitIfArgIsNotArrayOrIsNonEmpty_arr && [[ ${#exitIfArgIsNotArrayOrIsNonEmpty_arr[@]} -gt 0 ]]; then
		traceAndDie "the passed argument \033[0;36m%s\033[0m is a non empty array" "${!exitIfArgIsNotArrayOrIsNonEmpty_arr}"
	fi
}

function checkIsInitialisedArray() {
	if (($# != 1)); then
		traceAndDie "One argument needs to be passed to checkIsInitialisedArray, the array name, given \033[0;36m%s\033[0m\n" "$#"
	fi
	recursiveDeclareP "$1" | grep '(' >/dev/null
}

function checkArgIsArrayWithTuples() {
	if (($# != 5)); then
		logError "Five arguments need to be passed to checkArgIsArrayWithTuples, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: array            name of the array to check'
		echo >&2 '2: tupleNum         the number of values of each tuple'
		echo >&2 '3: tupleRepresents  what does the tuple represent (used in error message)'
		echo >&2 '4: argNumberOrName  what argument do we check (used in error message)'
		echo >&2 '5: describeTupleFn  function which describes how the tuples are built up'
		printStackTrace
		exit 9
	fi

	local -rn checkArgIsArrayWithTuples_paramArr=$1
	local -r tupleNum=$2
	local -r tupleRepresents=$3
	local -r argNumberOrName=$4
	local -r describeTupleFn=$5
	shift 5 || traceAndDie "could not shift by 5"

	exitIfArgIsNotFunction "$describeTupleFn" "$argNumberOrName"

	local funcName=${FUNCNAME[1]}
	if [[ $funcName == "exitIfArgIsNotArrayWithTuples" ]]; then
		funcName=${FUNCNAME[2]}
	fi

	local arrayDefinition
	arrayDefinition=$(recursiveDeclareP checkArgIsArrayWithTuples_paramArr) || traceAndDie "could not get array definition of %s" "${!checkArgIsArrayWithTuples_paramArr}"
	reg='declare -a.*'
	if ! [[ "$arrayDefinition" =~ $reg ]]; then
		logError "the passed array \033[0;36m%s\033[0m is broken" "${!checkArgIsArrayWithTuples_paramArr}"
		printf >&2 "The %s argument to %s needs to be a non-associative array containing %s, given:\n" "$argNumberOrName" "$funcName" "$tupleRepresents"
		echo >&2 "$arrayDefinition"
		echo >&2 ""
		"$describeTupleFn"
		printStackTrace
		exit 9
	fi

	local -r arrLength=${#checkArgIsArrayWithTuples_paramArr[@]}

	if ((arrLength == 0)); then
		logError "the passed array \033[0;36m%s\033[0m is broken, length was 0\033[0m" "${!checkArgIsArrayWithTuples_paramArr}"
		printf >&2 "The %s argument to %s needs to be a non-empty array containing %s, given:\n" "$argNumberOrName" "$funcName" "$tupleRepresents"
		"$describeTupleFn"
		printStackTrace
		exit 9
	fi

	if ! ((arrLength % tupleNum == 0)); then
		logError "the passed array \033[0;36m%s\033[0m is broken" "${!checkArgIsArrayWithTuples_paramArr}"
		printf >&2 "The %s argument to %s needs to be an array with %s-tuples containing %s, given:\n" "$argNumberOrName" "$funcName" "$tupleNum" "$tupleRepresents"
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
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkArgIsArrayWithTuples
	checkArgIsArrayWithTuples "$@" || exit $?
}

function checkArgIsFunction() {
	local name argNumberOrName
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(name argNumberOrName)
	parseFnArgs params "$@" || return $?

	if ! declare -F "$name" >/dev/null; then
		local declareP
		declareP=$(declare -p "$name" || printf "failure: \033[0;36m%s\033[0m is not a variable\n" "$name")
		local funcName=${FUNCNAME[1]}
		if [[ $funcName == "exitIfArgIsNotFunction" ]]; then
			funcName=${FUNCNAME[2]}
		fi
		traceAndReturnDying "the %s argument to %s needs to be a function/command, \033[0;36m%s\033[0m isn't one\nMaybe it is the name of a variable storing the name of a function?\nFollowing the output of: declare -p %s\n%s" \
			"$argNumberOrName" "$funcName" "$name" "$name" "$declareP"
	fi
}

function exitIfArgIsNotFunction() {
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkArgIsFunction
	checkArgIsFunction "$@" || exit $?
}

function checkArgIsBoolean() {
	local value argNumberOrName
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(value argNumberOrName)
	parseFnArgs params "$@" || return $?

	if ! [[ $value =~ ^(true|false)$ ]]; then
		local funcName=${FUNCNAME[1]}
		if [[ $funcName == "exitIfArgIsNotBoolean" ]]; then
			funcName=${FUNCNAME[2]}
		fi
		traceAndReturnDying "the %s argument to %s needs to be a boolean (either true or false), %s isn't one" \
			"$argNumberOrName" "$funcName" "$value"
	fi
}

function exitIfArgIsNotBoolean() {
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkArgIsBoolean
	checkArgIsBoolean "$@" || exit $?
}

function exitIfArgIsNotVersion() {
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkArgIsVersion
	checkArgIsVersion "$@" || exit $?
}

function checkArgIsVersion() {
	local versionRegex
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local value argNumberOrName
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(value argNumberOrName)
	parseFnArgs params "$@" || return $?

	if ! [[ "$value" =~ $versionRegex ]]; then
		local funcName=${FUNCNAME[1]}
		if [[ $funcName == "exitIfArgIsNotVersion" ]]; then
			funcName=${FUNCNAME[2]}
		fi
		traceAndReturnDying "the %s argument to %s needs to match vX.Y.Z(-RC...) was %s" \
			"$argNumberOrName" "$funcName" "$value"
	fi
}

function checkCommandExists() {
	if (($# != 1 && $# != 2)); then
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
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkCommandExists
	checkCommandExists "$@" || exit $?
}

function exitIfVarsNotAlreadySetBySource() {
	for varName in "$@"; do
		if ! [[ -v "$varName" ]] || [[ -z ${!varName} ]]; then
			traceAndDie "looks like \$%s was not defined by %s where this file (%s) was sourced" "$varName" "${BASH_SOURCE[2]:-${BASH_SOURCE[1]}}" "${BASH_SOURCE[0]}"
		fi
	done
}

function exitIfVariablesNotDeclared() {
	for variableName in "$@"; do
		if ! declare -p "$variableName" 2>/dev/null | grep -q 'declare --'; then
			logError "you need to \`declare\` (\`local\`) the variable \033[0;36m%s\033[0m otherwise we write to the global scope (you can also \`declare\` it in the global scope)" "$variableName"
			printStackTrace
			exit 1
		fi
	done
}

function checkPathIsInsideOf() {
	if (($# != 2)); then
		logError "Two arguments need to be passed to checkPathIsInsideOf, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: pathToCheck     the path which should be inside of rootDir'
		echo >&2 '2: rootDir         the root directory'
		printStackTrace
		exit 9

	fi
	local path=$1
	local rootDir=$2
	local pathAbsolute rootDirectoryAbsolute
	pathAbsolute="$(realpath -m "$path")" || return $?
	rootDirectoryAbsolute="$(realpath -m "$rootDir")" || return $?
	[[ "$pathAbsolute" == "$rootDirectoryAbsolute"* ]]
}

function checkPathNamedIsInsideOf() {
	local path name rootDir
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(path name rootDir)
	parseFnArgs params "$@" || return $?

	# shellcheck disable=SC2310			# we are aware of that ! will disable set -e for checkPathIsInsideOf
	if ! checkPathIsInsideOf "$path" "$rootDir"; then
		returnDying "the given \033[0;36m%s\033[0m %s not inside of %s" "$name" "$pathAbsolute" "$rootDir" || return $?
	fi
}

function exitIfPathNamedIsOutsideOf() {
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkPathNamedIsInsideOf
	checkPathNamedIsInsideOf "$@" || exit $?
}
