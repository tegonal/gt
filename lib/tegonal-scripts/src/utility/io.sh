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
#  utility function dealing with Input/Output
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
#
#    # First tries to set chmod 777 to the directory and all files within it and then deletes the directory
#    deleteDirChmod777 ".git"
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

function withCustomOutputInput() {
	# prefix variables as the callback function might use variables from an outer scope and we would shadow those
	local withCustomOutputInput_outputNr=$1
	local withCustomOutputInput_inputNr=$2
	local withCustomOutputInput_fun=$3
	shift 3 || traceAndDie "could not shift by 3"

	exitIfArgIsNotFunction "$withCustomOutputInput_fun" 3

	local withCustomOutputInput_tmpFile
	withCustomOutputInput_tmpFile=$(mktemp /tmp/tegonal-scripts-io.XXXXXXXXX)
	eval "exec ${withCustomOutputInput_outputNr}>\"$withCustomOutputInput_tmpFile\"" || traceAndDie "could not create output file descriptor %s" "$withCustomOutputInput_outputNr"
	eval "exec ${withCustomOutputInput_inputNr}<\"$withCustomOutputInput_tmpFile\"" || traceAndDie "could not create input file descriptor %s" "$withCustomOutputInput_inputNr"
	# don't fail if we cannot delete the tmp file, if this should happen, then the system should clean-up the file when the process ends
	rm "$withCustomOutputInput_tmpFile" || true

	$withCustomOutputInput_fun "$@"

	eval "exec ${withCustomOutputInput_outputNr}>&-"
	eval "exec ${withCustomOutputInput_inputNr}<&-"
}

function deleteDirChmod777() {
	local -r dir=$1
	shift 1 || traceAndDie "could not shift by 1"
	# e.g files in .git will be write-protected and we don't want sudo for this command
	# yet, if it fails, then we ignore the problem and still try to delete the folder
	chmod -R 777 "$dir" || true
	rm -r "$dir"
}
