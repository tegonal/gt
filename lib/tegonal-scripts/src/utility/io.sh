#!/usr/bin/env bash
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
#  utility function dealling with Input/Ouput
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
#
#    function readFile() {
#    	cat "$1" >&3
#    	echo "reading from 4 which was written to 3"
#    	local line
#    	while read -u 4 -r line; do
#    		echo "$line"
#    	done
#    }
#
#    # creates file descriptors 3 (output) and 4 (input) based on temporary files
#    # executes readFile and closes the file descriptors again
#    withCustomOutputInput 3 4 readFile "my-file.txt"
#
###################################
set -euo pipefail

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function withCustomOutputInput() {
	local outputNr=$1
	local inputNr=$2
	local fun=$3
	shift 3

	checkArgIsFunction "$fun" 3

	local tmpFile
	tmpFile=$(mktemp /tmp/tegonal-scripts-io.XXXXXXXXX)
	eval "exec ${outputNr}>\"$tmpFile\""
	eval "exec ${inputNr}<\"$tmpFile\""
	rm "$tmpFile"

	$fun "$@"

	eval "exec ${outputNr}>&-"
	eval "exec ${inputNr}<&-"
}
