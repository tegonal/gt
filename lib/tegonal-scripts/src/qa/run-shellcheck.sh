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
#  function which searches for *.sh files within defined directories and runs shellcheck on each file with
#  predefined settings i.a. sets `-s bash`
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
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
set -euo pipefail

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"

function runShellcheck() {
	if ! (($# == 2)); then
		logError "Two parameters need to be passed to runShellcheck, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: dirs         name of array which contains directories in which *.sh files are searched'
		echo >&2 '2: sourcePath   equivalent to shellcheck''s -P, path to search for sourced files, separated by :'
		printStackTrace
		exit 9
	fi
	local -rn directories=$1
	local -r sourcePath=$2

	checkArgIsArray directories 1

	local -i fileWithIssuesCounter=0
	local -i fileCounter=0
	local script
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
