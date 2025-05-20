#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v4.8.1
#
#######  Description  #############
#
#  utility functions for processing strings
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
#    source "$dir_of_tegonal_scripts/utility/string-utils.sh"
#
#    # will output v4\.2\.0
#    escapeRegex "v4.2.0"
#
#    # useful in combination with grep which does not support literal searches:
#    # escapes to tegonal\+
#    pattern=$(escapeRegex "tegonal+")
#    grep -E "$pattern"
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

function escapeRegex() {
	local -r pattern='s/[.[\*$^(){}+?|\\]/\\&/g'
	if (($# == 0)); then
		sed "$pattern"
	elif (($# == 1)); then
		sed "$pattern" <<<"$1"
	else
		traceAndDie "you need to either pass one element which shall be escaped or none in which case we read from stdin, given: %s" "$#"
	fi
}
