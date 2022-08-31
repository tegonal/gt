#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.5.0-SNAPSHOT
#
#######  Description  #############
#
#  're-pull' command of gget: utility to pull files defined in pulled.tsv for all or one previously defined remote
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # for each remote in .gget
#    # - re-pull files defined in .gget/remotes/<remote>/pulled.tsv which are missing locally
#    gget re-pull
#
#    # re-pull files defined in .gget/remotes/tegonal-scripts/pulled.tsv which are missing locally
#    gget re-pull -r tegonal-scripts
#
#    # pull all files defined in .gget/remotes/tegonal-scripts/pulled.tsv regardless if they already exist locally or not
#    gget re-pull -r tegonal-scripts --only-missing false
#
#    # uses a custom working directory and re-pulls files of remote tegonal-scripts which are missing locally
#    gget re-pull -r tegonal-scripts -w .github/.gget
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GGET_VERSION='v0.5.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	declare -r dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gget/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_gget/pulled-utils.sh"
sourceOnce "$dir_of_gget/utils.sh"
sourceOnce "$dir_of_gget/gget-pull.sh"
sourceOnce "$dir_of_gget/gget-remote.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget_re_pull() {
	local startTime endTime elapsed
	startTime=$(date +%s.%3N)

	local defaultWorkingDir
	source "$dir_of_gget/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	local -r onlyMissingPattern="--only-missing"

	local remote workingDir autoTrust onlyMissing
	# shellcheck disable=SC2034
	local -ar params=(
		remote "$remotePattern" '(optional) if set, only the remote with this name is reset, otherwise all are reset'
		workingDir "$workingDirPattern" "$workingDirParamDocu"
		autoTrust "$autoTrustPattern" "$autoTrustParamDocu"
		onlyMissing "$onlyMissingPattern" "(optional) if set, then only files which do not exist locally are pulled, otherwise all are re-pulled -- default: true"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# re-pull all files of remote tegonal-scripts which are missing locally
			gget re-pull -r tegonal-scripts

			# re-pull all files of all remotes which are missing locally
			gget re-pull

			# re-pull all files (not only missing) of remote tegonal-scripts, imports gpg keys without manual consent if necessary
			gget re-pull -r tegonal-scripts --only-missing false --auto-trust true
		EOM
	)

	parseArguments params "$examples" "$GGET_VERSION" "$@"
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v onlyMissing ]]; then onlyMissing=true; fi
	exitIfNotAllArgumentsSet params "$examples" "$GGET_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local -i pulled=0
	local -i skipped=0
	local -i errors=0

	function gget_re_pull_countError() {
		local -r entryFile=$1
		local -r remote=$2
		shift 2
		logError "could not fetch \033[0;36m%s\033[0m from remote %s" "$entryFile" "$remote"
		((++errors))
		return 1
	}

	function gget_re_pull_rePullInternal() {
		local -r remote=$1
		shift 1 || die "could not shift by 1"

		function gget_re_pull_rePullInternal_callback() {
			local entryTag entryFile _entryRelativePath entryAbsolutePath
			# params is required for parseFnArgs thus:
			# shellcheck disable=SC2034
			local -ra params=(entryTag entryFile _entryRelativePath entryAbsolutePath)
			parseFnArgs params "$@"

			# we know that set -e is disabled for gget_re_pull_countError due to ||
			#shellcheck disable=SC2310
			parentDir=$(dirname "$entryAbsolutePath") || gget_re_pull_countError "$entryFile" "$remote" || return $?
			if [[ $onlyMissing == false ]] || ! [[ -f $entryAbsolutePath ]]; then
				if gget_pull -w "$workingDirAbsolute" -r "$remote" -t "$entryTag" -p "$entryFile" -d "$parentDir" --chop-path true --auto-trust "$autoTrust"; then
					((++pulled))
				else
					gget_re_pull_countError "$entryFile" "$remote"
				fi
			elif [[ $onlyMissing == true ]]; then
				((++skipped))
				logInfo "skipping \033[0;36m%s\033[0m since it already exists locally at %s" "$entryFile" "$entryAbsolutePath"
			fi
		}
		# we know that set -e is disabled for gget_re_pull_countError due to ||
		#shellcheck disable=SC2310
		readPulledTsv "$workingDirAbsolute" "$remote" gget_re_pull_rePullInternal_callback 5 6 || gget_re_pull_countError "$entryFile" "$remote" || return $?
	}

	function gget_re_pull_rePullRemote() {
		local -r remote=$1
		shift 1
		withCustomOutputInput 5 6 gget_re_pull_rePullInternal "$remote"
	}

	function gget_re_pull_allRemotes() {
		gget_remote_list -w "$workingDirAbsolute" >&7
		local remote
		while read -u 8 -r remote; do
			gget_re_pull_rePullRemote "$remote"
		done
	}

	if [[ -n $remote ]]; then
		gget_re_pull_rePullRemote "$remote"
	else
		withCustomOutputInput 7 8 gget_re_pull_allRemotes
	fi

	endTime=$(date +%s.%3N)
	elapsed=$(bc <<<"scale=3; $endTime - $startTime")
	if ((errors == 0)); then
		logSuccess "%s files re-pulled in %s seconds, %s skipped" "$pulled" "$elapsed" "$skipped"
		if ((skipped > 0)) && [[ $onlyMissing == true ]]; then
			logInfo "In case you want to re-fetch also existing files, then use: %s false" "$onlyMissingPattern"
		fi
	else
		logWarning "%s files re-pulled in %s seconds, %s skipped, %s errors occurred, see above" "$pulled" "$elapsed" "$skipped" "$errors"
		return 1
	fi
}

${__SOURCED__:+return}
gget_re_pull "$@"
