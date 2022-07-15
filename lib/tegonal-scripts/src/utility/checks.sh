#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.7.0
#
#######  Description  #############
#
#  Functions to check declarations
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -eu
#    declare dir_of_tegonal_scripts
#    # Assuming tegonal's scripts are in the same directory as your script
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#
#    function foo() {
#    	source "$dir_of_tegonal_scripts/utility/checks.sh"
#
#    	# shellcheck disable=SC2034
#    	local -rn arr=$1
#    	checkArgIsArray arr 1
#    }
#
###################################
set -eu

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"

function checkArgIsArray() {
	local -rn arr1=$1
	local argNumber=$2

	reg='declare -a.*'
	local arrayDefinition
	arrayDefinition="$(set -e && recursiveDeclareP arr1)"
	if ! [[ $arrayDefinition =~ $reg ]]; then
		logError "the array \033[1;34m%s\033[0m defined in %s is broken." "${!arr1}" "${BASH_SOURCE[2]:-${BASH_SOURCE[1]}}"
		printf >&2 "the %s argument to %s needs to be a non-associative array, given:\n" "$argNumber" "${FUNCNAME[1]}"
		echo >&2 "$arrayDefinition"
		return 9
	fi
}
