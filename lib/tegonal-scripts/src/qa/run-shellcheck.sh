#!/usr/bin/env bash
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
#  function which searches for *.sh files within defined directories and runs shellcheck on each file with
#  predefined settings i.a. sets `-s bash`
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -eu
#    declare dir_of_tegonal_scripts
#    # Assuming tegonal's scripts are in the same directory as your script
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#    source "$dir_of_tegonal_scripts/qa/run-shellcheck.sh"
#
#    # shellcheck disable=SC2034
#    declare -a dirs=(
#    	"$dir_of_tegonal_scripts"
#    	"$dir_of_tegonal_scripts/../scripts"
#    	"$dir_of_tegonal_scripts/../spec"
#    )
#    declare sourcePath="$dir_of_tegonal_scripts"
#    runShellcheck dirs "$sourcePath"
#
###################################
set -eu

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"

function runShellcheck() {
	if ! (($# == 2)); then
		logError "Two parameter need to be passed to runShellcheck\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#" "${BASH_SOURCE[1]}"
		echo >&2 '1. dirs		 name of array which contains directories in which *.sh files are searched'
		echo >&2 '2. sourcePath		 equivalent to shellcheck''s -P, path to search for sourced files, separated by :'
		return 9
	fi
	local -rn directories=$1
	local -r sourcePath=$2

	checkArgIsArray directories 1

	local -i fileWithIssuesCounter=0
	local -i fileCounter=0
	while read -r -d $'\0' script; do
		((++fileCounter))
		declare output

		output=$(shellcheck -C -x -o all -P "$sourcePath" "$script" || true)
		if ! [[ $output == "" ]]; then
			printf "%s\n" "$output"
			((++fileWithIssuesCounter))
		fi
		if ((fileWithIssuesCounter >= 5)); then
			logInfoWithoutNewline "Already found issues in %s files, going to stop the analysis now in order to keep the output small" "$fileWithIssuesCounter"
			break
		fi
		printf "."
	done < <(find "${directories[@]}" -name '*.sh' -print0)
	printf "\n"

	if ((fileWithIssuesCounter > 0)); then
		die "found shellcheck issues in %s files" "$fileWithIssuesCounter"
	else
		logSuccess "no shellcheck issues found, analysed %s files" "$fileCounter"
	fi
}
