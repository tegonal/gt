#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.1
#######  Description  #############
#
#  script which should be sourced and sets up variables and functions for the scripts
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#
#    if ! [[ -v dir_of_tegonal_scripts ]]; then
#    	# Assumes your script is in (root is project folder) e.g. /src or /scripts and
#    	# the tegonal scripts have been pulled via gt and put into /lib/tegonal-scripts
#    	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#    fi
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

# shellcheck disable=SC2034		# global var used in log.sh
declare -A TEGONAL_SCRIPTS_SUPPRESSED_DEPRECATION=()
# shellcheck disable=SC2034		# global var used in log.sh
declare TEGONAL_SCRIPTS_ERROR_ON_DEPRECATION=true

#TODO 5.0.0 rename file to setup_tegonal_scripts.sh -- this way consumers will not run into shellcheck issues when they name a file setup.sh as well

if (($# != 1)); then
	printf >&2 "\033[0;31mERROR\033[0m: You need to pass the path to the tegonal scripts directory as first argument. Following an example\n"
	echo >&2 "source \"\$dir_of_tegonal_scripts/setup.sh\" \"\$dir_of_tegonal_scripts\""
	exit 9
fi

declare dir_of_tegonal_scripts
if ! dir_of_tegonal_scripts=$(realpath "$1"); then
	printf >&2 "\033[0;31mERROR\033[0m: looks like the passed dir_of_tegonal_scripts is not a realpath: %s" "$1"
	exit 9
fi
readonly dir_of_tegonal_scripts
source "$dir_of_tegonal_scripts/utility/source-once.sh"
