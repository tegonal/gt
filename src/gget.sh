#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.1.0-SNAPSHOT
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

set -e

if ! [ -x "$(command -v "git")" ]; then
	printf >&2 "\033[1;31mERROR\033[0m: git is not installed (or not in PATH), please install it (https://git-scm.com/downloads)\n"
	exit 100
fi

if [[ $# -lt 1 ]]; then
	printf >&2 "\033[1;31mERROR\033[0m: At least one parameter needs to be passed\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
	echo >&2 '1. command     one of: pull, remote'
	echo >&2 '2... args...   command specific arguments'
	exit 9
fi

scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"

function remote() {
	"$scriptDir/gget-remote.sh" "$@"
}

function pull() {
	"$scriptDir/gget-pull.sh" "$@"
}

declare command=$1
shift
if [[ "$command" =~ ^(pull|remote)$ ]]; then
	"$command" "$@"
elif [[ "$command" == "--help" ]]; then
	cat <<-EOM
		Use one of the following commands:
		pull     pull files from a remote
		remote   manage remotes
	EOM
else
	printf >&2 "\033[1;31mERROR\033[0m: unknown command %s, expected one of pull, remote\n" "$command"
	exit 9
fi
