#!/usr/bin/env bash
# shellcheck disable=SC2059
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
#  Utility function which returns the `declare` statement of a variable with given name where it recursively calls
#  itself as long as `declare -p varName` results in `declare -n ...`
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    # shellcheck disable=SC2034
#    set -euo pipefail
#    shopt -s inherit_errexit
#
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    source "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"
#
#    declare -i tmp=1
#    declare -n ref1=tmp
#    declare -n ref2=ref1
#    declare -n ref3=ref2
#
#    declare r0 r1 r2 r3
#    r0=$(recursiveDeclareP tmp)
#    r1=$(recursiveDeclareP ref1)
#    r2=$(recursiveDeclareP ref2)
#    r3=$(recursiveDeclareP ref3)
#
#    printf "%s\n" "$r0" "$r1" "$r2" "$r3"
#    # declare -i tmp="1"
#    # declare -i tmp="1"
#    # declare -i tmp="1"
#    # declare -i tmp="1"
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

function recursiveDeclareP() {
	if (($# != 1)); then
		traceAndDie "you need to pass the variable name, whose declaration statement shall be determined, to recursiveDeclareP"
	fi

	definition=$(declare -p "$1") || echo "executing 'declare -p $1' failed, see previous error message further above"
	local -r reg='^declare -n(r)? [^=]+=\"([^\"]+)\"$'
	while [[ $definition =~ $reg ]]; do
		definition=$(declare -p "${BASH_REMATCH[2]}" || echo "executing 'declare -p ${BASH_REMATCH[2]}' failed, see previous error message further above")
	done
	echo "$definition"
}
