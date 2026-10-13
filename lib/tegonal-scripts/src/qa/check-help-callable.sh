#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.1.0
#######  Description  #############
#
#  function which calls given scripts by passing --help and checks that the exit code is 99 as expected
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$scriptsDir/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
#    source "$dir_of_tegonal_scripts/qa/check-help-callable.sh"
#
#    # shellcheck disable=SC2034   # is passed by name to checkHelpCallable
#    declare -a scripts=(
#    	"$scriptsDir/release.sh"
#    	"$scriptsDir/prepare-next-dev-cycle.sh"
#    )
#    checkHelpCallable scripts
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/array-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function checkHelpCallable() {
	if (($# != 1)); then
		logError "Exactly one argument need to be passed to checkHelpCallable, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: scripts        name of array which contains scripts which shall be called'
		printStackTrace
		exit 9
	fi
	local -rn checkHelpCallable_arr=$1
	shift 1 || traceAndDie "could not shift by 1"
	exitIfArgIsNotArrayOrIsEmpty checkHelpCallable_arr 1

	local script
	for script in "${checkHelpCallable_arr[@]}"; do
		local status=0
		"$script" --help >/dev/null || status=$?
		[[ $status -eq 99 ]] || die "looks like calling %s failed unexpectedly, see above" "$script"
	done
	logSuccess "all given scripts could have been called with --help and exited with 99"
}

${__SOURCED__:+return}
checkHelpCallable "$@"
