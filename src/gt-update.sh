#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.17.3
#######  Description  #############
#
#  'update' command of gt: utility to update already pulled files
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # updates all pulled files of all remotes to latest tag
#    gt update
#
#    # updates all pulled files of remote tegonal-scripts to latest tag
#    gt update -r tegonal-scripts
#
#    # updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
#    gt update -r tegonal-scripts -t v1.0.0
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v0.17.3'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gt/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_gt/pulled-utils.sh"
sourceOnce "$dir_of_gt/utils.sh"
sourceOnce "$dir_of_gt/gt-pull.sh"
sourceOnce "$dir_of_gt/gt-remote.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gt_update() {
	local startTime endTime elapsed
	startTime=$(date +%s.%3N)

	local defaultWorkingDir
	source "$dir_of_gt/common-constants.source.sh" || die "could not source common-constants.source.sh"

	local remote workingDir autoTrust tag
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ar params=(
		remote "$remoteParamPattern" '(optional) if set, only the files of this remote are updated, otherwise all'
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
		autoTrust "$autoTrustParamPattern" "$autoTrustParamDocu"
		tag "$tagParamPattern" "(optional) define from which tag files shall be pulled, only valid if remote via $remoteParamPattern is specified"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# updates all pulled files of all remotes to latest tag
			gt update

			# updates all pulled files of remote tegonal-scripts to latest tag
			gt update -r tegonal-scripts

			# updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
			gt update -r tegonal-scripts -t v1.0.0
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@"
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v tag ]]; then tag=""; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	if [[ -n $tag && -z $remote ]]; then
		die "tag can only be defined if a remote is specified via %s" "$remoteParamPattern"
	fi

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local -i pulled=0
	local -i errors=0

	function gt_update_incrementError() {
		local -r entryFile=$1
		local -r remote=$2
		shift 2 || die "could not shift by 2"
		logError "could not pull \033[0;36m%s\033[0m from remote %s" "$entryFile" "$remote"
		((++errors))
	}

	# shellcheck disable=SC2317   # called by name
	function gt_update_rePullInternal() {
		local -r remote=$1
		shift 1 || die "could not shift by 1"

		local tagToPull
		if [[ -n $tag ]]; then
			tagToPull="$tag"
		else
			reInitialiseGitDirIfDotGitNotPresent "$workingDirAbsolute" "$remote"
			tagToPull=$(latestRemoteTagIncludingChecks "$workingDirAbsolute" "$remote") || die "could not determine latest tag, see above"
		fi

		function gt_update_rePullInternal_callback() {
			local _entryTag entryFile _entryRelativePath entryAbsolutePath
			# shellcheck disable=SC2034   # is passed by name to parseFnArgs
			local -ra params=(_entryTag entryFile _entryRelativePath entryAbsolutePath)
			parseFnArgs params "$@"

			#shellcheck disable=SC2310		# we know that set -e is disabled for gt_update_incrementError due to ||
			parentDir=$(dirname "$entryAbsolutePath") || gt_update_incrementError "$entryFile" "$remote" || return
			if gt_pull -w "$workingDirAbsolute" -r "$remote" -t "$tagToPull" -p "$entryFile" -d "$parentDir" --chop-path true --auto-trust "$autoTrust"; then
				((++pulled))
			else
				gt_update_incrementError "$entryFile" "$remote"
			fi
		}
		readPulledTsv "$workingDirAbsolute" "$remote" gt_update_rePullInternal_callback 5 6
	}

	function gt_update_rePullRemote() {
		local -r remote=$1
		shift 1 || die "could not shift by 1"

		exitIfRemoteDirDoesNotExist "$workingDir" "$remote"

		withCustomOutputInput 5 6 gt_update_rePullInternal "$remote"
	}

	function gt_update_allRemotes() {
		gt_remote_list_raw -w "$workingDirAbsolute" >&7
		local -i count=0
		local remote
		while read -u 8 -r remote; do
			gt_update_rePullRemote "$remote"
			((++count))
		done
		if ((count == 0)); then
			logInfo "Nothing updated as no remote is defined yet.\nUse the \033[0;35mgt remote add ...\033[0m command to specify one -- for more info: gt remote add --help"
		fi
	}

	if [[ -n $remote ]]; then
		gt_update_rePullRemote "$remote"
	else
		withCustomOutputInput 7 8 gt_update_allRemotes
	fi

	endTime=$(date +%s.%3N)
	elapsed=$(bc <<<"scale=3; $endTime - $startTime")
	if ((errors == 0)); then
		logSuccess "%s files updated in %s seconds" "$pulled" "$elapsed"
	else
		logWarning "%s files updated in %s seconds, %s errors occurred, see above" "$pulled" "$elapsed" "$errors"
		return 1
	fi
}

${__SOURCED__:+return}
gt_update "$@"
