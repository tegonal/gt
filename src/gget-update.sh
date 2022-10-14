#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.10.0-SNAPSHOT
#
#######  Description  #############
#
#  'update' command of gget: utility to update already pulled files
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # updates all pulled files of all remotes to latest tag
#    gget update
#
#    # updates all pulled files of remote tegonal-scripts to latest tag
#    gget update -r tegonal-scripts
#
#    # updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
#    gget update -r tegonal-scripts -t v1.0.0
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GGET_VERSION='v0.10.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gget/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_gget/pulled-utils.sh"
sourceOnce "$dir_of_gget/utils.sh"
sourceOnce "$dir_of_gget/gget-pull.sh"
sourceOnce "$dir_of_gget/gget-remote.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget_update() {
	local startTime endTime elapsed
	startTime=$(date +%s.%3N)

	local defaultWorkingDir
	source "$dir_of_gget/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	local remote workingDir autoTrust tag
	# shellcheck disable=SC2034
	local -ar params=(
		remote "$remotePattern" '(optional) if set, only the files of this remote are updated, otherwise all'
		workingDir "$workingDirPattern" "$workingDirParamDocu"
		autoTrust "$autoTrustPattern" "$autoTrustParamDocu"
		tag "$tagPattern" "(optional) define from which tag files shall be pulled, only valid if remote via $remotePattern is specified"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# updates all pulled files of all remotes to latest tag
			gget update

			# updates all pulled files of remote tegonal-scripts to latest tag
			gget update -r tegonal-scripts

			# updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
			gget update -r tegonal-scripts -t v1.0.0
		EOM
	)

	parseArguments params "$examples" "$GGET_VERSION" "$@"
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v tag ]]; then tag=""; fi
	exitIfNotAllArgumentsSet params "$examples" "$GGET_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	if [[ -n $tag && -z $remote ]]; then
		die "tag can only be defined if a remote is specified via %s" "$remotePattern"
	fi

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local -i pulled=0
	local -i errors=0

	function gget_update_incrementError() {
		local -r entryFile=$1
		local -r remote=$2
		shift 2
		logError "could not pull \033[0;36m%s\033[0m from remote %s" "$entryFile" "$remote"
		((++errors))
		return 1
	}

	function gget_update_rePullInternal() {
		local -r remote=$1
		shift 1 || die "could not shift by 1"

		local tagToPull
		if [[ -n $tag ]]; then
			tagToPull="$tag"
		else
			reInitialiseGitDirIfDotGitNotPresent "$workingDirAbsolute" "$remote"
			tagToPull=$(latestRemoteTagIncludingChecks "$workingDirAbsolute" "$remote") || die "could not determine latest tag, see above"
		fi

		function gget_update_rePullInternal_callback() {
			local _entryTag entryFile _entryRelativePath entryAbsolutePath
			# params is required for parseFnArgs thus:
			# shellcheck disable=SC2034
			local -ra params=(_entryTag entryFile _entryRelativePath entryAbsolutePath)
			parseFnArgs params "$@"

			# we know that set -e is disabled for gget_update_incrementError due to ||
			#shellcheck disable=SC2310
			parentDir=$(dirname "$entryAbsolutePath") || gget_update_incrementError "$entryFile" "$remote" || return $?
			if gget_pull -w "$workingDirAbsolute" -r "$remote" -t "$tagToPull" -p "$entryFile" -d "$parentDir" --chop-path true --auto-trust "$autoTrust"; then
				((++pulled))
			else
				gget_update_incrementError "$entryFile" "$remote"
			fi
		}
		readPulledTsv "$workingDirAbsolute" "$remote" gget_update_rePullInternal_callback 5 6
	}

	function gget_update_rePullRemote() {
		local -r remote=$1
		shift 1

		exitIfRemoteDirDoesNotExist "$workingDir" "$remote"

		withCustomOutputInput 5 6 gget_update_rePullInternal "$remote"
	}

	function gget_update_allRemotes() {
		gget_remote_list_raw -w "$workingDirAbsolute" >&7
		local -i count=0
		local remote
		while read -u 8 -r remote; do
			gget_update_rePullRemote "$remote"
			((++count))
		done
		if ((count == 0)); then
			logInfo "Nothing updated as no remote is defined yet.\nUse the \033[0;35mgget remote add ...\033[0m command to specify one -- for more info: gget remote add --help"
		fi
	}

	if [[ -n $remote ]]; then
		gget_update_rePullRemote "$remote"
	else
		withCustomOutputInput 7 8 gget_update_allRemotes
	fi

	endTime=$(date +%s.%3N)
	elapsed=$(bc <<<"scale=3; $endTime - $startTime")
	if ((errors == 0)); then
		logSuccess "%s files updated in %s seconds" "$pulled" "$elapsed"
	else
		logWarning "%s files re-pulled in %s seconds, %s errors occurred, see above" "$pulled" "$elapsed" "$errors"
		return 1
	fi
}

${__SOURCED__:+return}
gget_update "$@"
