#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.14.0
#
#######  Description  #############
#
#  Intended to parse command line arguments. Provides a simple way to parse named arguments including a documentation
#  if one uses the parameter `--help` and shows the version if one uses --version.
#  I.e. that also means that `--help` and `--version` are reserved patterns and should not be used by your
#  script/function.
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    MY_LIBRARY_VERSION="v1.0.3"
#
#    if ! [[ -v dir_of_tegonal_scripts ]]; then
#    	# Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#    fi
#    sourceOnce "$dir_of_tegonal_scripts/utility/parse-utils.sh"
#
#    function myParseFunction() {
#    	while (($# > 0)); do
#    		if [[ $1 == "--version" ]]; then
#    			shift || die "could not shift by 1"
#    			printVersion "$MY_LIBRARY_VERSION"
#    		fi
#    		#...
#    	done
#    }
#
#######	Limitations	#############
#
#	1. Does not support repeating arguments (last wins and overrides previous definitions)
#	2. Supports named arguments only (e.g. not possible to pass positional arguments after the named arguments)
#
#	=> take a look at https://github.com/ko1nksm/getoptions if you need something more powerful
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

function printVersion() {
	if ! (($# == 1)); then
		logError "One argument needs to be passed to printVersion, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: version   the version which shall be shown if one uses --version'
		printStackTrace
		exit 9
	fi
	local version=$1
	logInfo "Version of %s is:\n%s" "$(basename "${BASH_SOURCE[3]:-${BASH_SOURCE[2]}}")" "$version"
}
