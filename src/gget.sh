#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.1.0
#
#######  Description  #############
#
#  Utility to pull a file or a directory from a git repository.
#  Per default, each file is verified against its signature (*.sig file) which needs to be alongside the file.
#  Corresponding public GPG keys (*.asc) need to be placed in gget's workdir (.gget by default) under WORKDIR/remotes/<remote>/public-keys
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # gget pull ...
#    # take at look at gget-pull.doc.sh for more information
#
#    # gget remote add ...
#    # gget remote remove ...
#    # gget remote list ...
#    # take at look at gget-remote.doc.sh for more information
#
###################################
set -euo pipefail
declare -x GGET_VERSION='v0.1.0'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	declare -r dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gget/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"

function gget() {
	if (($# < 1)); then
		logError "At least one parameter needs to be passed to gget, given \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#" "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
		echo >&2 '1. command     one of: pull, remote'
		echo >&2 '2... args...   command specific arguments'
		return 9
	fi

	if ! [[ -x "$(command -v "git")" ]]; then
		die "git is not installed (or not in PATH), please install it (https://git-scm.com/downloads)"
	fi

	local -r command=$1
	shift
	if [[ "$command" =~ ^(pull|remote)$ ]]; then
		sourceOnce "$dir_of_gget/gget-$command.sh"
		"gget-$command" "$@"
	elif [[ "$command" == "--help" ]]; then
		cat <<-EOM
			Use one of the following commands:
			pull     pull files from a remote
			remote   manage remotes
		EOM
	else
		returnDying "unknown command \033[0;36m%s\033[0m, expected one of pull, remote" "$command"
	fi
}

${__SOURCED__:+return}
gget "$@"
