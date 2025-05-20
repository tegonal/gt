#!/usr/bin/env bash
# shellcheck disable=SC2059
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
#  Functions which help in doing cleanup in e.g. scripts/cleanup-on-push-to-main.sh
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#
#    projectDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
#
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/cleanups.sh"
#
#    # e.g. in scripts/cleanup-on-push-to-main.sh
#    function cleanupOnPushToMain() {
#    	removeUnusedSignatures "$projectDir"
#    	logSuccess "cleanup done"
#    }
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

function removeUnusedSignatures() {
	if (($# != 1)); then
		logError "One argument needs to be passed to removeUnusedSignatures, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: projectDir	the path to the root directory of the project'
		printStackTrace
		exit 9
	fi
	local projectRootDir=$1
	shift 1 || traceAndDie "could not shift by 1"

	find "$projectRootDir" \
		-type f \
		-name "*.sig" \
		-not -path "$projectRootDir/.gt/signing-key.public.asc.sig" \
		-not -path "$projectRootDir/.gt/remotes/*/public-keys/*.sig" \
		-print0 |
		while read -r -d $'\0' sigFile; do
			if ! [[ -f ${sigFile::${#sigFile}-4} ]]; then
				logInfo "remove unused signature \033[0;36m%s\033[0m as the corresponding file does no longer exist" "$sigFile"
				rm "$sigFile"
			fi
		done
}
