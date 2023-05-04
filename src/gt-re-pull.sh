#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.12.0
#
#######  Description  #############
#
#  're-pull' command of gt: utility to pull files defined in pulled.tsv for all or one previously defined remote
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # for each remote in .gt
#    # - re-pull files defined in .gt/remotes/<remote>/pulled.tsv which are missing locally
#    gt re-pull
#
#    # re-pull files defined in .gt/remotes/tegonal-scripts/pulled.tsv which are missing locally
#    gt re-pull -r tegonal-scripts
#
#    # pull all files defined in .gt/remotes/tegonal-scripts/pulled.tsv regardless if they already exist locally or not
#    gt re-pull -r tegonal-scripts --only-missing false
#
#    # uses a custom working directory and re-pulls files of remote tegonal-scripts which are missing locally
#    gt re-pull -r tegonal-scripts -w .github/.gt
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v0.12.0'

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
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gt_re_pull() {
	local startTime endTime elapsed
	startTime=$(date +%s.%3N)

	local defaultWorkingDir
	source "$dir_of_gt/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	local -r onlyMissingPattern="--only-missing"

	local remote workingDir autoTrust onlyMissing
	# shellcheck disable=SC2034   # is passed to parseArguments by name
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
			gt re-pull -r tegonal-scripts

			# re-pull all files of all remotes which are missing locally
			gt re-pull

			# re-pull all files (not only missing) of remote tegonal-scripts, imports gpg keys without manual consent if necessary
			gt re-pull -r tegonal-scripts --only-missing false --auto-trust true
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@"
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v onlyMissing ]]; then onlyMissing=true; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local -i pulled=0
	local -i skipped=0
	local -i errors=0

	function gt_re_pull_incrementError() {
		local -r entryFile=$1
		local -r remote=$2
		shift 2
		logError "could not pull \033[0;36m%s\033[0m from remote %s" "$entryFile" "$remote"
		((++errors))
		return 1
	}

  # shellcheck disable=SC2317   # called by name
	function gt_re_pull_rePullInternal() {
		local -r remote=$1
		shift 1 || die "could not shift by 1"

		function gt_re_pull_rePullInternal_callback() {
			local entryTag entryFile _entryRelativePath entryAbsolutePath
			# params is required for parseFnArgs thus:
			# shellcheck disable=SC2034   # is passed to parseFnArgs by name
			local -ra params=(entryTag entryFile _entryRelativePath entryAbsolutePath)
			parseFnArgs params "$@"

			# we know that set -e is disabled for gt_re_pull_incrementError due to ||
			#shellcheck disable=SC2310
			parentDir=$(dirname "$entryAbsolutePath") || gt_re_pull_incrementError "$entryFile" "$remote" || return $?
			if [[ $onlyMissing == false ]] || ! [[ -f $entryAbsolutePath ]]; then
				if gt_pull -w "$workingDirAbsolute" -r "$remote" -t "$entryTag" -p "$entryFile" -d "$parentDir" --chop-path true --auto-trust "$autoTrust"; then
					((++pulled))
				else
					gt_re_pull_incrementError "$entryFile" "$remote"
				fi
			elif [[ $onlyMissing == true ]]; then
				((++skipped))
				logInfo "skipping \033[0;36m%s\033[0m since it already exists locally at %s" "$entryFile" "$entryAbsolutePath"
			fi
		}

		readPulledTsv "$workingDirAbsolute" "$remote" gt_re_pull_rePullInternal_callback 5 6
	}

	function gt_re_pull_rePullRemote() {
		local -r remote=$1
		shift 1
		withCustomOutputInput 5 6 gt_re_pull_rePullInternal "$remote"
	}

	function gt_re_pull_allRemotes() {
		gt_remote_list_raw -w "$workingDirAbsolute" >&7
		local -i count=0
		local remote
		while read -u 8 -r remote; do
			gt_re_pull_rePullRemote "$remote"
			((++count))
		done
		if ((count == 0)); then
			logInfo "Nothing to re-pull as no remote is defined yet.\nUse the \033[0;35mgt remote add ...\033[0m command to specify one -- for more info: gt remote add --help"
		fi
	}

	if [[ -n $remote ]]; then
		gt_re_pull_rePullRemote "$remote"
	else
		withCustomOutputInput 7 8 gt_re_pull_allRemotes
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
gt_re_pull "$@"
