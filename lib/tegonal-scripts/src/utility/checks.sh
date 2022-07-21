#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.11.1
#
#######  Description  #############
#
#  Functions to check declarations
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
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
#    	checkArgIsArray arr 1
#    	checkArgIsFunction "$fn" 2
#    }
#
#    checkCommandExists "cat"
#
#    # give a hint how to install the command
#    checkCommandExists "git" "please install it via https://git-scm.com/downloads"
#
###################################
set -euo pipefail

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"

function checkArgIsArray() {
	local -rn arr1=$1
	local -r argNumber=$2

	reg='declare -a.*'
	local arrayDefinition
	arrayDefinition="$(set -e && recursiveDeclareP arr1)"
	if ! [[ $arrayDefinition =~ $reg ]]; then
		traceAndReturnDying "the passed array \033[0;36m%s\033[0m is broken.\nThe %s argument to %s needs to be a non-associative array, given:\n%s" \
			"${!arr1}" "$argNumber" "${FUNCNAME[1]}" "$arrayDefinition"
	fi
}

function checkArgIsFunction() {
	local -r name=$1
	local -r argNumber=$2

	if ! declare -F "$name" >/dev/null; then
		traceAndReturnDying "the %s argument to %s needs to be a function/command, %s isn't one\nMaybe it is a variable storing the name of a function?\nFollowing the output of: declare -p %s\n%s" \
			"$argNumber" "${FUNCNAME[1]}" "$name" "$name" "$(declare -p "$name" || echo "failure, is not a variable")"
	fi
}

function checkCommandExists() {
	local -r name=$1
	if ! [[ -x "$(command -v "$name")" ]]; then
		returnDying "$name is not installed (or not in PATH)${2:-""}"
	else
		return 0
	fi
}
