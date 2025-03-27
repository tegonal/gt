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
#  utility functions for dealing with arrays
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
#    sourceOnce "$dir_of_tegonal_scripts/utility/array-utils.sh"
#
#    declare regex
#    regex=$(joinByChar '|' my regex alternatives)
#    declare -a commands=(add delete list config)
#    regex=$(joinByChar '|' "${commands[@]}")
#
#    joinByString ', ' a list of strings and the previously defined "$regex"
#    declare -a names=(alwin darius fabian mike mikel robert oliver thomas)
#    declare employees
#    employees=$(joinByString ", " "${names[@]}")
#    echo ""
#    echo "Tegonal employees are currently: $employees"
#
#    function startingWithA() {
#    	[[ $1 == a* ]]
#    }
#    declare -a namesStartingWithA=()
#    arrFilter names namesStartingWithA startingWithA
#    declare -p namesStartingWithA
#
#    declare -a everySecondName
#    arrTakeEveryX names everySecondName 2 0
#    declare -p everySecondName
#    declare -a everySecondNameStartingFrom1
#    arrTakeEveryX names everySecondNameStartingFrom1 2 1
#    declare -p everySecondNameStartingFrom1
#
#    arrStringEntryMaxLength names # 6
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

joinByChar() {
	local IFS="$1"
	shift 1 || traceAndDie "could not shift by 1"
	echo "$*"
}

joinByString() {
	if (($# < 1)); then
		logError "At least one arguments need to be passed to joinByString, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: separator  separator used to separate the args'
		echo >&2 '2... args...  args as such'
		printStackTrace
		exit 9
	fi
	if (($# > 1)); then
		local separator="$1"
		local firstArg="$2"
		shift 2 || traceAndDie "could not shift by 2"
		printf "%s" "$firstArg" "${@/#/$separator}"
	fi
}

function arrFilter() {
	if (($# != 3)); then
		logError "Three arguments needs to be passed to arrFilter, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn    name of the array to filter'
		echo >&2 '2: arrayOut   name of the array which will contain the result'
		echo >&2 '3: predicate  function which what argument do we check (used in error message)'
		printStackTrace
		exit 9
	fi

	local -rn arrFilter_arrIn=$1
	local -rn arrFilter_arrOut=$2
	local -r predicate=$3
	shift 3 || traceAndDie "could not shift by 3"

	exitIfArgIsNotFunction "$predicate" 3

	local -ri arrFilter_arrInLength="${#arrFilter_arrIn[@]}"

	local -i i
	for ((i = 0; i < arrFilter_arrInLength; ++i)); do
		local entry="${arrFilter_arrIn[$i]}"
		if "$predicate" "$entry" "$i"; then
			arrFilter_arrOut+=("$entry")
		fi
	done
}

function arrTakeEveryX() {
	if (($# != 4)); then
		logError "Four arguments needs to be passed to arrTakeEveryX, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn      name of the array to filter'
		echo >&2 '2: arrayOut     name of the array which will contain the result'
		echo >&2 '3: everyXEntry  e.g. 2, every second entry'
		echo >&2 '3: offset  			e.g. 0, starting by entry 0 (in combination with everyXEntry 2 would mean entry 0, 2, 4...'
		printStackTrace
		exit 9
	fi
	# shellcheck disable=SC2034   # is passed by name to arrFilter
	local -rn arrFilterMod_arrIn=$1
	# shellcheck disable=SC2034   # is passed by name to arrFilter
	local -rn arrFilterMod_arrOut=$2
	local -ri modulo=$3
	local -ri offset=$4
	shift 4 || traceAndDie "could not shift by 4"

  # shellcheck disable=SC2317   # is passed by name to arrFilter
	function arrFilterMod_fn() {
		local -r index=$2
		(((index - offset) % modulo == 0))
	}
	arrFilter arrFilterMod_arrIn arrFilterMod_arrOut arrFilterMod_fn
	unset arrFilterMod_fn
}

function arrStringEntryMaxLength() {
	if (($# != 1)); then
		logError "One argument needs to be passed to arrStringEntryMaxLength, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: array      name of the array which contains strings'
		printStackTrace
		exit 9
	fi
	local -rn arrStringEntryMaxLength_arr=$1
	shift 1 || traceAndDie "could not shift by 1"

	local -i i maxLength=0 arrLength="${#arrStringEntryMaxLength_arr[@]}"
	for ((i = 0; i < arrLength; ++i)); do
		local entry="${arrStringEntryMaxLength_arr[i]}"
		local length=${#entry}
		if ((length > maxLength)); then
			maxLength=$length
		fi
	done
	echo "$maxLength"
}
