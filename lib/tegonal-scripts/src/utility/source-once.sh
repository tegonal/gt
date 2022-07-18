#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.9.0
#
#######  Description  #############
#
#  Utility functions wrapping printf and prefixing the message with a coloured INFO, WARNING or ERROR.
#  logError writes to stderr and logWarning and logInfo to stdout
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    source "$dir_of_tegonal_scripts/utility/source-once.sh"
#
#    sourceOnce "foo.sh"    # creates a variable named foo__sh which acts as guard and sources foo.sh
#    sourceOnce "foo.sh"    # will source nothing as foo__sh is already defined
#    unset foo__sh          # unsets the guard
#    sourceOnce "foo.sh"    # is sourced again and the guard established
#
#
#
#    # creates a variable named bar__foo__sh which acts as guard and sources bar/foo.sh
#    sourceOnce "bar/foo.sh"
#
#    # will source nothing, only the parent dir + file is used as identifier
#    # i.e. the corresponding guard is bar__foo__sh and thus this file is not sourced
#    sourceOnce "asdf/bar/foo.sh"
#
###################################
set -euo pipefail

function sourceOnce() {
	if (($# < 1)); then
		printf >&2 "you need to pass at least the file you want to source to sourceOnce in \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "${BASH_SOURCE[1]}"
		echo >&2 '1. file       the file to source'
		echo >&2 '2... args...  additional parameters which are passed to the source command'
		return 9
	fi

	local guard
	guard=$(readlink -m "$1" | perl -0777 -pe "s@(?:.*/([^/]+)/)?([^/]+)\$@\$1__\$2@;" -pe "s/[-.]/_/g")

	if ! [[ -v "$guard" ]]; then
		printf -v "$guard" "%s" "true"
		if ! [[ -f $1 ]]; then
			if [[ -d $1 ]]; then
				traceAndDie "file is a directory, cannot source %s" "$1"
			fi
			traceAndDie "file does not exist, cannot source %s" "$1"
		fi

		# shellcheck disable=SC2034
		declare __SOURCED__=true
		# shellcheck disable=SC1090
		source "$@"
		unset __SOURCED__
	fi
}

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
