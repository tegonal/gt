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
#  Utility function which returns the `declare` statement of a variable with given name where it recursively calls
#  itself as long as `declare -p varName` results in `declare -n ...`
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    # shellcheck disable=SC2034
#    set -eu
#
#    declare dir_of_tegonal_scripts
#    # Assuming tegonal's scripts are in the same directory as your script
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#    source "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"
#
#    declare -i tmp=1
#    declare -n ref1=tmp
#    declare -n ref2=ref1
#    declare -n ref3=ref2
#
#    printf "%s\n" \
#    	"$(set -e; recursiveDeclareP tmp)" \
#    	"$(set -e; recursiveDeclareP ref1)" \
#    	"$(set -e; recursiveDeclareP ref2)" \
#    	"$(set -e; recursiveDeclareP ref3)"
#    # declare -i tmp="1"
#    # declare -i tmp="1"
#    # declare -i tmp="1"
#    # declare -i tmp="1"
#
###################################
set -eu

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"

function recursiveDeclareP() {
	if ! (($# == 1)); then
		logError "One parameter needs to be passed to recursiveDeclareP\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#" "${BASH_SOURCE[1]}"
		echo >&2 '1. variableName		 the name of the variable whose declaration statement shall be determined'
		return 9
	fi

	definition=$(declare -p "$1")
	local -r reg='^declare -n(r)? [^=]+=\"([^\"]+)\"$'
	while [[ $definition =~ $reg ]]; do
		definition=$(declare -p "${BASH_REMATCH[2]}" || echo "executing 'declare -p ${BASH_REMATCH[2]}' failed, see previous error message further above")
	done
	echo "$definition"
}
