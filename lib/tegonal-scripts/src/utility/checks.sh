#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.12.0
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
#    	exitIfArgIsNotArray arr 1
#    	exitIfArgIsNotFunction "$fn" 2
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
	shift 2

	reg='^declare -a.*'
	local arrayDefinition
	# we are not failing (with || die...) on this line as the if will fail afterwards
	arrayDefinition="$(recursiveDeclareP checkArgIsArray_arr)"
	if ! [[ $arrayDefinition =~ $reg ]]; then
		traceAndReturnDying "the passed array \033[0;36m%s\033[0m is broken.\nThe %s argument to %s needs to be a non-associative array, given:\n%s" \
			"${!checkArgIsArray_arr}" "$argNumber" "${FUNCNAME[1]}" "$arrayDefinition"
	fi
}

function exitIfArgIsNotArray() {
	# we are aware of that || will disable set -e for checkArgIsArray
	# shellcheck disable=SC2310
	checkArgIsArray "$@" || exit $?
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
		traceAndReturnDying "the %s argument to %s needs to be a function/command, %s isn't one\nMaybe it is a variable storing the name of a function?\nFollowing the output of: declare -p %s\n%s" \
			"$argNumber" "${FUNCNAME[1]}" "$name" "$name" "$declareP"
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
	file=$(command -v "$name") || return $?
	if ! [[ -x $file ]]; then
		returnDying "$name is not installed (or not in PATH) ${2:-""}"
	fi
}

function exitIfCommandDoesNotExist() {
	# we are aware of that || will disable set -e for checkCommandExists
	# shellcheck disable=SC2310
	checkCommandExists "$@" || exit $?
}
