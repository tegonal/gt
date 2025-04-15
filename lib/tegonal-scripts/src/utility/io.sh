#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.0
#######  Description  #############
#
#  utility function dealing with Input/Output
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
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function withCustomOutputInput() {
	if (($# < 3)); then
		logError "At least three arguments need to be passed to withCustomOutputInput, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '  1: outputNr   the file descriptor number for the output (i.e. in which you want to write)'
		echo >&2 '  2: inputNr    the file descriptor number for the input (i.e. from which you want to read)'
		echo >&2 '  3: callback		the name of the callback function which shall be called'
		echo >&2 '...: vararg			arguments which are passed to the callback function'
		printStackTrace
		exit 9
	fi
	# prefix variables as the callback function might use variables from an outer scope and we would shadow those
	local withCustomOutputInput_outputNr=$1
	local withCustomOutputInput_inputNr=$2
	local withCustomOutputInput_fun=$3
	shift 3 || traceAndDie "could not shift by 3"

	exitIfArgIsNotFunction "$withCustomOutputInput_fun" 3

	local withCustomOutputInput_tmpFile
	withCustomOutputInput_tmpFile=$(mktemp -t tegonal-scripts-io.XXXXXXXXX) || traceAndDie "could not create a temporary directory"
	eval "exec ${withCustomOutputInput_outputNr}>\"$withCustomOutputInput_tmpFile\"" || traceAndDie "could not create output file descriptor %s" "$withCustomOutputInput_outputNr"
	eval "exec ${withCustomOutputInput_inputNr}<\"$withCustomOutputInput_tmpFile\"" || traceAndDie "could not create input file descriptor %s" "$withCustomOutputInput_inputNr"
	# don't fail if we cannot delete the tmp file, if this should happen, then the system should clean-up the file when the process ends
	# same same if $withCustomOutputInput_fun should fail/exit, we don't setup a trap, the system should clean it up
	rm "$withCustomOutputInput_tmpFile" || true

	local exitCode=0
	$withCustomOutputInput_fun "$@" || exitCode=$?

	eval "exec ${withCustomOutputInput_outputNr}>&-"
	eval "exec ${withCustomOutputInput_inputNr}<&-"
	return "$exitCode"
}

function deleteDirChmod777() {
	local -r dir=$1
	shift 1 || traceAndDie "could not shift by 1"
	# e.g files in .git will be write-protected and we don't want sudo for this command
	# yet, if it fails, then we ignore the problem and still try to delete the folder
	chmod -R 777 "$dir" || true
	rm -r "$dir"
}
