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
#  script which should be sourced and sets up variables and functions for the scripts
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -eu
#
#    if ! [[ -v dir_of_tegonal_scripts ]]; then
#    	# Assumes your script is in (root is project folder) e.g. /src or /scripts and
#    	# the tegonal scripts have been pulled via gget and put into /lib/tegonal-scripts
#    	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#    fi
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
#
###################################

if ! (($# == 1)); then
	printf >&2 "\033[0;31mERROR\033[0m: You need to pass the path to the tegonal scripts directory as first argument. Following an example\n"
	echo >&2 "source \"\$dir_of_tegonal_scripts/setup.sh\" \"\$dir_of_tegonal_scripts\""
	exit
fi

declare -r dir_of_tegonal_scripts="$1"
source "$dir_of_tegonal_scripts/utility/source-once.sh"
