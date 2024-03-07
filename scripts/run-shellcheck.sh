#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License 1.2
#         /___/                           Please report bugs and contribute back your improvements
#                                         Version: v0.17.0-SNAPSHOT
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$scriptsDir/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/qa/run-shellcheck.sh"

function customRunShellcheck() {
	declare srcDir="$scriptsDir/../src"

	# shellcheck disable=SC2034   # is passed by name to runShellcheck
	declare -a dirs=("$srcDir" "$scriptsDir" "$scriptsDir/../install.sh")
	declare sourcePath="$srcDir:$scriptsDir:$dir_of_tegonal_scripts"
	runShellcheck dirs "$sourcePath"

	local -r gh_commons_dir="$scriptsDir/../.gt/remotes/tegonal-gh-commons"
	logInfo "analysing $gh_commons_dir/pull-hook.sh"

	# shellcheck disable=SC2034   # is passed by name to runShellcheck
	local -ra dirs2=("$gh_commons_dir")
	runShellcheck dirs2 "$sourcePath" -name "pull-hook.sh"
}

${__SOURCED__:+return}
customRunShellcheck "$@"
