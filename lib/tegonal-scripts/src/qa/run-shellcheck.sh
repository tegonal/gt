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
#  function which searches for *.sh files within defined paths (directories or a single *.sh) and
#  runs shellcheck on each file with predefined settings i.a. sets `-s bash`
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
#    source "$dir_of_tegonal_scripts/qa/run-shellcheck.sh"
#
#    # shellcheck disable=SC2034   # is passed by name to runShellcheck
#    declare -a dirs=(
#    	"$dir_of_tegonal_scripts"
#    	"$dir_of_tegonal_scripts/../scripts"
#    	"$dir_of_tegonal_scripts/../spec"
#    )
#    declare sourcePath="$dir_of_tegonal_scripts"
#    runShellcheck dirs "$sourcePath"
#
#    # pass the working directory of gt which usually is .gt in the root of your repository
#    # this will run shellcheck on all pull-hook.sh files
#    runShellcheckPullHooks ".gt"
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
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/array-utils.sh"

function runShellcheck() {
	exitIfCommandDoesNotExist "shellcheck" "execute $dir_of_tegonal_scripts/ci/install-shellcheck.sh (if pulled) or see https://github.com/koalaman/shellcheck#installing"

	if (($# < 2)); then
		logError "At least two parameters need to be passed to runShellcheck, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: dirs         name of array which contains paths in which *.sh files are searched'
		echo >&2 '2: sourcePath   equivalent to shellcheck'"'"'s -P, path to search for sourced files, separated by :'
		echo >&2 '3... args       additional args which are passed to the find command'
		printStackTrace
		exit 9
	fi
	local -rn runShellcheck_paths=$1
	local -r sourcePath=$2
	shift 2 || traceAndDie "could not shift by 2"

	exitIfArgIsNotArrayOrIsEmpty runShellcheck_paths 1

	local path
	for path in "${runShellcheck_paths[@]}"; do
		if ! find "$path" -maxdepth 1 -path "$path" >/dev/null; then
			die "cannot find in path %s, see above" "$path"
		fi
	done

	shellcheck --version

	local -i fileWithIssuesCounter=0
	local -i fileCounter=0
	local -i skipped=0
	local script
	if ! while read -r -d $'\0' script; do
		if [[ -L $script ]]; then
			((++skipped))
		else
			((++fileCounter))
			declare output
			output=$(shellcheck --check-sourced --color=always --external-sources --enable=all --source-path="$sourcePath" "$script" 2>&1 || true)
			if [[ $output != "" ]]; then
				printf "%s\n" "$output"
				((++fileWithIssuesCounter))
			fi
			if ((fileWithIssuesCounter >= 5)); then
				logInfoWithoutNewline "Already found issues in %s files, going to stop the analysis now in order to keep the output small" "$fileWithIssuesCounter"
				break
			fi
		fi
		printf "."
	done < <(
		find "${runShellcheck_paths[@]}" -name '*.sh' "$@" -print0 ||
			# `while read` will fail because there is no \0
			true
	); then
		printf "\n"
		die "problem during while read or find, see above"
	fi
	printf "\n"

	if ((fileWithIssuesCounter > 0)); then
		die "found shellcheck issues in %s files (%s symlinks skipped)" "$fileWithIssuesCounter" "$skipped"
	elif ((fileCounter == 0)); then
		die "looks suspicious, no files where analysed (%s symlinks skipped), watch out for errors above" "$skipped"
	else
		local runShellcheck_paths_as_string
		runShellcheck_paths_as_string=$(joinByChar $'\n' "${runShellcheck_paths[@]}")
		logSuccess "no shellcheck issues found, analysed %s files (%s symlinks skipped) in paths:\n%s" "$fileCounter" "$skipped" "$runShellcheck_paths_as_string"
	fi
}

function runShellcheckPullHooks() {
	if (($# != 1)); then
		logError "Exactly one parameter needs to be passed to runShellcheckPullHooks, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: gt_dir  working directory of gt'
		printStackTrace
		exit 9
	fi
	local -r gt_dir=$1

	local -r gt_remote_dir="$gt_dir/remotes"
	logInfo "analysing $gt_remote_dir/**/pull-hook*.sh"

	# shellcheck disable=SC2034   # is passed by name to runShellcheck
	local -ra dirs=("$gt_remote_dir")
	local sourcePath="$dir_of_tegonal_scripts"
	runShellcheck dirs "$sourcePath" -name "pull-hook*.sh"
}
