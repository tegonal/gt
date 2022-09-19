#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.7.1
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
#    # gget remote add ...
#    # gget remote remove ...
#    # gget remote list ...
#    # take at look at gget-remote.doc.sh for more information
#
#    # gget pull ...
#    # take at look at gget-pull.doc.sh for more information
#
#    # gget re-pull ...
#    # take at look at gget-re-pull.doc.sh for more information
#
#    # gget reset ...
#    # take at look at gget-reset.doc.sh for more information
#
#    # gget update ...
#    # take at look at gget-update.doc.sh for more information
#
#    # gget self-update
#    # take at look at gget-self-update.doc.sh for more information
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GGET_VERSION='v0.7.1'

if ! [[ -v dir_of_gget ]]; then
	declare intermediateSource=${BASH_SOURCE[0]:-$0}
	declare intermediateDir=""
	while [[ -L $intermediateSource ]]; do
		intermediateDir=$(cd -P "$(dirname "$intermediateSource")" >/dev/null && pwd)
		intermediateSource=$(readlink "$intermediateSource")
		if [[ $intermediateSource != /* ]]; then
			intermediateSource=$intermediateDir/$intermediateSource
		fi
	done
	dir_of_gget=$(cd -P "$(dirname "$intermediateSource")" >/dev/null && pwd)
	readonly dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gget/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-commands.sh"

function gget_source() {
	local -r command=$1
	shift || die "could not shift by 1"
	sourceOnce "$dir_of_gget/gget-$command.sh"
}

function gget() {
	# is used in parseCommands but shellcheck is not able to deduce this, thus:
	# shellcheck disable=SC2034
	local -ra commands=(
		pull "pull files from a previously defined remote"
		re-pull "re-pull files defined in pulled.tsv of a specific or all remotes"
		remote "manage remotes"
		reset "reset one or all remotes (re-establish gpg and re-pull files)"
		update "update pulled files to latest or particular version"
		self-update "update gget to the latest version"
	)
	parseCommands commands "$GGET_VERSION" gget_source gget_ "$@"
}

${__SOURCED__:+return}
gget "$@"
