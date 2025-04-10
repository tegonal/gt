#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.6.1
#######  Description  #############
#
#  function which calls shellspec in case the command exists and otherwise prints a warning
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo "please update to bash 5, see errors above"; exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    source "$dir_of_tegonal_scripts/qa/run-shellspec-if-installed.sh"
#
#    runShellspecIfInstalled
#
#    # you can also pass arguments to shellspec
#    runShellspecIfInstalled --jobs 2
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo "please update to bash 5, see errors above"; exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function runShellspecIfInstalled() {
	if checkCommandExists "shellspec" 2>/dev/null; then
		local shellspecVersion
		shellspecVersion="$(shellspec -version)"
		logInfo "Running shellspec $shellspecVersion ..."
		shellspec "$@"
	else
		logWarning "shellspec is not installed, skipping running specs.\nConsider to install it, execute $dir_of_tegonal_scripts/ci/install-shellcheck.sh (if pulled) or see https://github.com/shellspec/shellspec#installation"
	fi
}
