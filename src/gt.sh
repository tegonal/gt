#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.0.4
#######  Description  #############
#
#  Utility to pull a file or a directory from a git repository.
#  Per default, each file is verified against its signature (*.sig file) which needs to be alongside the file.
#  Corresponding public GPG keys (*.asc) need to be placed in gt's workdir (.gt by default) under WORKDIR/remotes/<remote>/public-keys
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # gt remote add ...
#    # gt remote remove ...
#    # gt remote list ...
#    # take at look at gt-remote.doc.sh for more information
#
#    # gt pull ...
#    # take at look at gt-pull.doc.sh for more information
#
#    # gt re-pull ...
#    # take at look at gt-re-pull.doc.sh for more information
#
#    # gt reset ...
#    # take at look at gt-reset.doc.sh for more information
#
#    # gt update ...
#    # take at look at gt-update.doc.sh for more information
#
#    # gt self-update
#    # take at look at gt-self-update.doc.sh for more information
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v1.0.4'

if ! [[ -v dir_of_gt ]]; then
	declare intermediateSource=${BASH_SOURCE[0]:-$0}
	declare intermediateDir=""
	while [[ -L $intermediateSource ]]; do
		intermediateDir=$(cd -P "$(dirname "$intermediateSource")" >/dev/null && pwd)
		intermediateSource=$(readlink "$intermediateSource")
		if [[ $intermediateSource != /* ]]; then
			intermediateSource=$intermediateDir/$intermediateSource
		fi
	done
	dir_of_gt=$(cd -P "$(dirname "$intermediateSource")" >/dev/null && pwd)
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-commands.sh"

function gt_source() {
	local -r command=$1
	shift 1 || traceAndDie "could not shift by 1"
	sourceOnce "$dir_of_gt/gt-$command.sh"
}

function gt() {
	# shellcheck disable=SC2034   # is passed by name to parseCommands
	local -ra commands=(
		pull "pull files from a previously defined remote"
		re-pull "re-pull files defined in pulled.tsv of a specific or all remotes"
		remote "manage remotes"
		reset "reset one or all remotes (re-establish gpg and re-pull files)"
		update "update pulled files to latest or particular version"
		self-update "update gt to the latest version"
	)
	parseCommands commands "$GT_VERSION" gt_source gt_ "$@"
}

${__SOURCED__:+return}
gt "$@"
