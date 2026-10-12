#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.13.0
#######  Description  #############
#
#  utility functions for dealing with arrays
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
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
#    # shellcheck disable=SC2034	# passed by name to arrPartitionTuples
#    declare -a attendees=(
#    	alice 30 berlin
#    	bob 25 zurich
#    	carol 41 lausanne
#    )
#    declare -a youngerThan30 olderOr30
#    function isYoungerThan30() {
#    	(($2 < 30))
#    }
#    # fills the arrays youngerThan30 and olderOr30m with the tuples from the array attendees
#    # based on the result of the function isYoungerThan30. The second argument defines the size of the tuples in attendees.
#    arrPartitionTuples attendees 3 youngerThan30 olderOr30 isYoungerThan30
#    declare -p youngerThan30
#    declare -p olderOr30
#
#    declare -a alineAndBob
#    # fills the array alineAndBob with the tuples from the array attendees which have either alice or bob as first
#    # element of the tuple where each tuple has 3 elements (defined by the second argument).
#    arrKeepTuplesByKey attendees 3 alice bob
#    declare -p alineAndBob
#
#    declare -a withoutBobAndCarol
#    # fills the array withoutBobAndCarol with the tuples from the array attendees which have neither bob nor carol as first
#    # element of the tuple where each tuple has 3 elements (defined by the second argument).
#    arrDropTuplesByKey attendees 3 bob carol
#    declare -p withoutBobAndCarol
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

joinByChar() {
	local IFS="$1"
	shift 1 || traceAndDie "could not shift by 1"
	echo "$*"
}

joinByString() {
	if (($# < 1)); then
		logError "At least one argument needs to be passed to joinByString, given \033[0;36m%s\033[0m\n" "$#"
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
		printf "\n"
	fi
}

function arrFilter() {
	if (($# != 3)); then
		logError "Three arguments need to be passed to arrFilter, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn    name of the array to filter'
		echo >&2 '2: arrayOut   name of the array which will contain the result'
		echo >&2 '3: predicate  name of the function which serves as predicate, passing the entry and index as arguments'
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

# since 4.13.0
function arrPartitionTuples() {
	if (($# != 5)); then
		logError "Five arguments need to be passed to arrPartitionTuples, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn     name of the (flat) array to partition'
		echo >&2 '2: tupleSize   number of consecutive entries which form a tuple, e.g. 3 for triples'
		echo >&2 '3: arrayTrue   name of the array which will contain all tuples for which the predicate returned true (flat as well)'
		echo >&2 '4: arrayFalse  name of the array which will contain all tuples for which the predicate returned false (flat as well)'
		echo >&2 '5: predicate   name of the function which serves as predicate, the entries of the tuple are passed as arguments'
		printStackTrace
		exit 9
	fi

	local -rn arrPartitionTuples_arrIn=$1
	local -ri arrPartitionTuples_size=$2
	local -rn arrPartitionTuples_arrTrue=$3
	local -rn arrPartitionTuples_arrFalse=$4
	local -r arrPartitionTuples_predicate=$5
	shift 5 || traceAndDie "could not shift by 5"

	exitIfArgIsNotArrayWithTuples arrPartitionTuples_arrIn "$arrPartitionTuples_size" "tuples" "first"
	exitIfArgIsNotFunction "$arrPartitionTuples_predicate" 5

	if ((arrPartitionTuples_size < 1)); then
		traceAndDie "tupleSize needs to be >= 1, given: $arrPartitionTuples_size"
	fi
	local -ri arrPartitionTuples_length="${#arrPartitionTuples_arrIn[@]}"

	if ((arrPartitionTuples_length % arrPartitionTuples_size != 0)); then
		traceAndDie "array has $arrPartitionTuples_length entries, which is not a multiple of tupleSize $arrPartitionTuples_size"
	fi

	local -i arrPartitionTuples_i
	local -a arrPartitionTuples_tuple
	for ((arrPartitionTuples_i = 0; arrPartitionTuples_i < arrPartitionTuples_length; arrPartitionTuples_i += arrPartitionTuples_size)); do
		arrPartitionTuples_tuple=("${arrPartitionTuples_arrIn[@]:arrPartitionTuples_i:arrPartitionTuples_size}")
		if "$arrPartitionTuples_predicate" "${arrPartitionTuples_tuple[@]}"; then
			arrPartitionTuples_arrTrue+=("${arrPartitionTuples_tuple[@]}")
		else
			arrPartitionTuples_arrFalse+=("${arrPartitionTuples_tuple[@]}")
		fi
	done
}

# since 4.13.0
function arrPartitionTuplesByKey() {
	if (($# < 5)); then
		logError "At least five arguments need to be passed to arrPartitionTuplesByKey, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn     name of the (flat) array to partition'
		echo >&2 '2: tupleSize   number of consecutive entries which form a tuple, e.g. 3 for triples'
		echo >&2 '3: arrayMatch  name of the array which will contain all tuples whose first entry equals one of the keys'
		echo >&2 '4: arrayRest   name of the array which will contain all other tuples'
		echo >&2 '5...: keys     one or more values to compare with the first entry of each tuple, fails if one of them does not occur'
		printStackTrace
		exit 9
	fi
	# shellcheck disable=SC2034   # is passed by name to arrPartitionTuples
	local -rn arrPartitionTuplesByKey_arrIn=$1
	local -ri arrPartitionTuplesByKey_size=$2
	# shellcheck disable=SC2034   # is passed by name to arrPartitionTuples
	local -rn arrPartitionTuplesByKey_arrMatch=$3
	# shellcheck disable=SC2034   # is passed by name to arrPartitionTuples
	local -rn arrPartitionTuplesByKey_arrRest=$4
	shift 4 || traceAndDie "could not shift by 4"

	# value is 0 as long as the key was not found as first entry of a tuple, 1 afterwards
	# shellcheck disable=SC2034   # is read and written by arrPartitionTuplesByKey_fn via dynamic scoping
	local -A arrPartitionTuplesByKey_keys=()
	local arrPartitionTuplesByKey_key
	for arrPartitionTuplesByKey_key in "$@"; do
		arrPartitionTuplesByKey_keys["$arrPartitionTuplesByKey_key"]=0
	done

	# shellcheck disable=SC2329   # is passed by name to arrPartitionTuples
	function arrPartitionTuplesByKey_fn() {
		[[ -n ${arrPartitionTuplesByKey_keys["$1"]+x} ]] || return 1
		arrPartitionTuplesByKey_keys["$1"]=1
	}
	arrPartitionTuples arrPartitionTuplesByKey_arrIn "$arrPartitionTuplesByKey_size" \
		arrPartitionTuplesByKey_arrMatch arrPartitionTuplesByKey_arrRest arrPartitionTuplesByKey_fn
	unset arrPartitionTuplesByKey_fn

	local -a arrPartitionTuplesByKey_missing=()
	for arrPartitionTuplesByKey_key in "$@"; do
		if ((arrPartitionTuplesByKey_keys["$arrPartitionTuplesByKey_key"] == 0)); then
			arrPartitionTuplesByKey_missing+=("$arrPartitionTuplesByKey_key")
		fi
	done
	if ((${#arrPartitionTuplesByKey_missing[@]} > 0)); then
		traceAndDie "the following keys were not found as first entry of a tuple in ${!arrPartitionTuplesByKey_arrIn}: ${arrPartitionTuplesByKey_missing[*]}"
	fi
}

function arrKeepTuplesByKey() {
	if (($# < 4)); then
		logError "At least four arguments need to be passed to arrKeepTuplesByKey, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn    name of the (flat) array'
		echo >&2 '2: tupleSize  number of consecutive entries which form a tuple'
		echo >&2 '3: arrayOut   name of the array which will contain the tuples whose first entry equals one of the keys'
		echo >&2 '4...: keys    one or more values to compare with the first entry of each tuple'
		printStackTrace
		exit 9
	fi
	# shellcheck disable=SC2034   # is passed by name to arrPartitionTuplesByKey
	local -a arrKeepTuplesByKey_discarded=()
	arrPartitionTuplesByKey "$1" "$2" "$3" arrKeepTuplesByKey_discarded "${@:4}"
}

function arrDropTuplesByKey() {
	if (($# < 4)); then
		logError "At least four arguments need to be passed to arrDropTuplesByKey, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn    name of the (flat) array'
		echo >&2 '2: tupleSize  number of consecutive entries which form a tuple'
		echo >&2 '3: arrayOut   name of the array which will contain the tuples whose first entry equals none of the keys'
		echo >&2 '4...: keys    one or more values to compare with the first entry of each tuple'
		printStackTrace
		exit 9
	fi
	# shellcheck disable=SC2034   # is passed by name to arrPartitionTuplesByKey
	local -a arrDropTuplesByKey_discarded=()
	arrPartitionTuplesByKey "$1" "$2" arrDropTuplesByKey_discarded "$3" "${@:4}"
}

function arrTakeEveryX() {
	if (($# != 4)); then
		logError "Four arguments need to be passed to arrTakeEveryX, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: arrayIn      name of the array to filter'
		echo >&2 '2: arrayOut     name of the array which will contain the result'
		echo >&2 '3: everyXEntry  e.g. 2, every second entry'
		echo >&2 '4: offset       e.g. 0, starting by entry 0 (in combination with everyXEntry 2 would mean entry 0, 2, 4...'
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

	# shellcheck disable=SC2329   # is passed by name to arrFilter
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
