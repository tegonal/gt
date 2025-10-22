#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.10.0
#######  Description  #############
#
#  function which runs shfmt on defined paths, ignoring *.doc.sh files.
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
#    source "$dir_of_tegonal_scripts/qa/run-shfmt.sh"
#
#    # shellcheck disable=SC2034   # is passed by name to runShfmt
#    declare -a dirs=(
#    	"$dir_of_tegonal_scripts"
#    	"$dir_of_tegonal_scripts/../scripts"
#    	"$dir_of_tegonal_scripts/../spec"
#    )
#    runShfmt dirs -not -name sh-to-exclude.sh
#
#    # pass the working directory of gt which usually is .gt in the root of your repository
#    # this will run shfmt on all pull-hook.sh files
#    runShfmtPullHooks ".gt"
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
sourceOnce "$dir_of_tegonal_scripts/utility/array-utils.sh"

function runShfmt() {
	exitIfCommandDoesNotExist "shfmt" "execute $dir_of_tegonal_scripts/ci/install-shfmt.sh (if pulled) or see hhttps://github.com/mvdan/sh/releases"

	if (($# < 1)); then
		logError "At least one argument needs to be passed to runShfmt, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: paths        name of array which contains paths in which *.sh files are searched'
		echo >&2 '2... args       additional args which are passed to the find command'
		printStackTrace
		exit 9
	fi
	local -rn runShfmt_paths=$1
	shift 1 || traceAndDie "could not shift by 2"

	exitIfArgIsNotArrayOrIsEmpty runShfmt_paths 1

	local path
	for path in "${runShfmt_paths[@]}"; do
		if ! find "$path" -maxdepth 1 -path "$path" >/dev/null; then
			die "cannot find in path %s, see above" "$path"
		fi
	done

	shfmtVersion="$(shfmt -version)"
	logInfo "Running shfmt $shfmtVersion ..."

	local hadErrors=false
	if ! while read -r -d $'\0' script; do
		shfmt -l -w "$script" || hadErrors=true
	done < <(
		find "${runShfmt_paths[@]}" -name '*.sh' "$@" -print0 ||
			# `while read` will fail because there is no \0
			true
	); then
		die "problem during while read or find, see above"
	fi

	if [[ $hadErrors == true ]]; then
		die "There were errors during shfmt, see above"
	else
		local runShfmt_paths_as_string
		runShfmt_paths_as_string=$(joinByChar $'\n' "${runShfmt_paths[@]}")
		logSuccess "formatted all files in paths:\n%s" "$runShfmt_paths_as_string"
	fi
}

function runShfmtPullHooks() {
	if (($# != 1)); then
		logError "Exactly one parameter needs to be passed to runShfmtPullHooks, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: gt_dir  working directory of gt'
		printStackTrace
		exit 9
	fi
	local -r gt_dir=$1

	local -r gt_remote_dir="$gt_dir/remotes"
	logInfo "formatting $gt_remote_dir/**/pull-hook*.sh"

	# shellcheck disable=SC2034   # is passed by name to runShfmt
	local -ra dirs=("$gt_remote_dir")
	runShfmt dirs -name "pull-hook*.sh"
}
