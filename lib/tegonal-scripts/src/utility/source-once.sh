#!/usr/bin/env bash
# shellcheck disable=SC2059
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.5.1
#######  Description  #############
#
#  Utility functions wrapping printf and prefixing the message with a coloured INFO, WARNING or ERROR.
#  logError writes to stderr and logWarning and logInfo to stdout
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    source "$dir_of_tegonal_scripts/utility/source-once.sh"
#
#    sourceOnce "foo.sh"    # creates a variable named sourceOnceGuard_foo__sh which acts as guard and sources foo.sh
#    sourceOnce "foo.sh"    # will source nothing as sourceOnceGuard_foo__sh is already defined
#    unset sourceOnceGuard_foo__sh          # unsets the guard
#    sourceOnce "foo.sh"    # is sourced again and the guard established
#    # you can also use sourceAlways instead of unsetting and using sourceOnce.
#    sourceAlways "foo.sh"
#
#    # creates a variable named sourceOnceGuard_bar__foo__sh which acts as guard and sources bar/foo.sh
#    sourceOnce "bar/foo.sh"
#
#    # will source nothing, only the parent dir + file is used as identifier
#    # i.e. the corresponding guard is sourceOnceGuard_bar__foo__sh and thus this file is not sourced
#    sourceOnce "asdf/bar/foo.sh"
#
#    declare guard
#    guard=$(determineSourceOnceGuard "src/bar.sh")
#    # In case you don't want that a certain file is sourced, then you can define the guard yourself
#    # this will prevent that */src/bar.sh is sourced
#    printf -v "$guard" "%s" "true"
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

function determineSourceOnceGuard() {
	if (($# != 1)); then
		traceAndDie "you need to pass the file name, for which we shall calculate the guard, to determineSourceOnceGuard"
	fi
	local -r file="$1"
	(readlink -f "$file" || realpath "$file") | perl -0777 -pe "s@(?:.*/([^/]+)/)?([^/]+)\$@sourceOnceGuard_\$1__\$2@;" -pe "s/[-.]/_/g" || die "was not able to determine sourceOnce guard for %s" "$file"
}

function sourceOnce_exitIfNotAtLeastOneArg() {
	if (($# < 1)); then
		printf >&2 "you need to pass at least the file you want to source to sourceOnce in \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "${BASH_SOURCE[1]}"
		echo >&2 '1. file       the file to source'
		echo >&2 '2... args...  additional parameters which are passed to the source command'
		printStackTraced
		exit 9
	fi
}

function sourceOnce() {
	sourceOnce_exitIfNotAtLeastOneArg "$@"

	local -r sourceOnce_file="$1"
	shift 1 || traceAndDie "could not shift by 1"

	local sourceOnce_guard
	sourceOnce_guard=$(determineSourceOnceGuard "$sourceOnce_file")
	local -r sourceOnce_guard

	if ! [[ -v "$sourceOnce_guard" ]]; then
		printf -v "$sourceOnce_guard" "%s" "true"
		if ! [[ -f $sourceOnce_file ]]; then
			if [[ -d $sourceOnce_file ]]; then
				traceAndDie "file is a directory, cannot source %s" "$sourceOnce_file"
			fi
			traceAndDie "file does not exist, cannot source %s" "$sourceOnce_file"
		fi

		# shellcheck disable=SC2034   # is used in the sourced file
		declare __SOURCED__=true
		# we know that shellcheck cannot follow the non-constant source we don't know the source and thus cannot help out
		# shellcheck disable=SC1090
		source "$sourceOnce_file" "$@" || die "there was an error sourcing %s, see above" "$sourceOnce_file"
		unset __SOURCED__
	fi
}

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"

# Use this function in case you want to source the given file even if it was previously sourced via sourceOnce
# but still want to set up a corresponding guard in order that a subsequent sourceOnce does no longer source the file
#
# if you don't want to setup a guard, then simply use `source` instead.
function sourceAlways() {
	sourceOnce_exitIfNotAtLeastOneArg "$@"

	local -r sourceAlways_file="$1"
	shift 1 || traceAndDie "could not shift by 1"

	local sourceAlways_guard
	sourceAlways_guard=$(determineSourceOnceGuard "$sourceAlways_file")
	unset "$sourceAlways_guard"
	sourceOnce "$sourceAlways_file" "$@"
}
