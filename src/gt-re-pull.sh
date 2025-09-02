#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.5.0-SNAPSHOT
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
#    # re-pull alls files defined in .gt/remotes/tegonal-scripts/pulled.tsv
#    # and trust all gpg-keys stored in .gt/remotes/tegonal-scripts/public-keys
#    # if the remotes gpg sotre is not yet set up
#    gt pull -r tegonal-scripts --auto-trust true
#
#    # uses a custom working directory and re-pulls files of remote tegonal-scripts which are missing locally
#    gt re-pull -w .github/.gt -r tegonal-scripts
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export GT_VERSION='v1.5.0-SNAPSHOT'

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
sourceOnce "$dir_of_tegonal_scripts/utility/date-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gt_re_pull() {
	local startTimestampInMs elapsedInSeconds
	startTimestampInMs="$(timestampInMs)" || true

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local defaultWorkingDir remoteParamPatternLong workingDirParamPatternLong tagParamPatternLong pathParamPatternLong
	local pullDirParamPatternLong chopPathParamPatternLong targetFileNamePatternLong autoTrustParamPatternLong
	local tagFilterParamPatternLong
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local -r onlyMissingPattern="--only-missing"

	local remote workingDir autoTrust onlyMissing
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ar params=(
		remote "$remoteParamPattern" '(optional) if set, only the remote with this name is reset, otherwise all are reset'
		onlyMissing "$onlyMissingPattern" "(optional) if set, then only files which do not exist locally are pulled, otherwise all are re-pulled -- default: true"
		autoTrust "$autoTrustParamPattern" "$autoTrustParamDocu"
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# re-pull all files of remote tegonal-scripts which are missing locally
			gt re-pull -r tegonal-scripts

			# re-pull all files of all remotes which are missing locally
			gt re-pull

			# re-pull all files (not only missing) of remote tegonal-scripts
			gt re-pull -r tegonal-scripts --only-missing false
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@" || return $?
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v onlyMissing ]]; then onlyMissing=true; fi

	# before we report about missing arguments we check if the working directory exists and
	# if it is inside of the call location
	exitIfWorkingDirDoesNotExist "$workingDir"
	exitIfPathNamedIsOutsideOf "$workingDir" "working directory" "$currentDir"

	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local -i pulled=0
	local -i skipped=0
	local -i errors=0

	function gt_re_pull_incrementError() {
		local -r entryFile=$1
		local -r remote=$2
		shift 2 || traceAndDie "could not shift by 2"
		logError "could not pull \033[0;36m%s\033[0m from remote %s" "$entryFile" "$remote"
		((++errors))
	}

	# shellcheck disable=SC2317   # called by name
	function gt_re_pull_rePullInternal() {
		local -r remote=$1
		shift 1 || traceAndDie "could not shift by 1"

		local repo
		source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

		local -a gt_pull_parsed_args
		gt_pull_parse_args gt_pull_parsed_args "$currentDir" \
			"$workingDirParamPatternLong" "$workingDirAbsolute" \
			"$remoteParamPatternLong" "$remote" \
			"$tagParamPatternLong" "tag-to-replace" \
			"$pathParamPatternLong" "source-to-replace" \
			"$pullDirParamPatternLong" "pull-dir-to-replace" \
			"$chopPathParamPatternLong" true \
			"$targetFileNamePatternLong" "target-to-replace" \
			"$tagFilterParamPatternLong" "tag-filter-to-replace" \
			"$autoTrustParamPatternLong" "$autoTrust" || return $?

		# shellcheck disable=SC2329 # gt_re_pull_rePullInternal_callback is called by name
		function gt_re_pull_rePullInternal_callback() {
			local entryTag entryFile entryRelativePath entryAbsolutePath entryTagFilter _entrySha512

			# shellcheck disable=SC2034   # is passed by name to parseFnArgs
			local -ra params=(entryTag entryFile entryRelativePath entryAbsolutePath entryTagFilter _entrySha512)
			parseFnArgs params "$@"

			local entryTargetFileName
			entryTargetFileName=$(basename "$entryRelativePath")

			local parentDir
			#shellcheck disable=SC2310		# we know that set -e is disabled for gt_re_pull_incrementError due to ||
			parentDir=$(dirname "$entryAbsolutePath") || gt_re_pull_incrementError "$entryFile" "$remote" || return
			if [[ $onlyMissing == false ]] || ! [[ -f $entryAbsolutePath ]]; then
				local startTimestampInMs elapsedInSeconds
				startTimestampInMs="$(timestampInMs)" || true
				gt_pull_parsed_args[2]=$entryTag
				gt_pull_parsed_args[3]=$entryFile
				gt_pull_parsed_args[4]=$parentDir
				gt_pull_parsed_args[6]=$entryTargetFileName
				gt_pull_parsed_args[7]=$entryTagFilter

				if gt_pull_internal_without_arg_checks "$currentDir" "$startTimestampInMs" "${gt_pull_parsed_args[@]}"; then
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
		gt_pull_cleanupRepo "$repo"
	}

	function gt_re_pull_rePullRemote() {
		local -r remote=$1
		shift 1 || traceAndDie "could not shift by 1"
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

	elapsedInSeconds="$(elapsedSecondsBasedOnTimestampInMs "$startTimestampInMs" || echo "<could not determine elapsed time>")"
	if ((errors == 0)); then
		logSuccess "%s files re-pulled in %s seconds, %s skipped" "$pulled" "$elapsedInSeconds" "$skipped"
		if ((skipped > 0)) && [[ $onlyMissing == true ]]; then
			logInfo "In case you want to re-fetch also existing files, then use: %s false" "$onlyMissingPattern"
		fi
	else
		logWarning "%s files re-pulled in %s seconds, %s skipped, %s errors occurred, see above" "$pulled" "$elapsedInSeconds" "$skipped" "$errors"
		return 1
	fi

	gt_checkForSelfUpdate
}

${__SOURCED__:+return}
gt_re_pull "$@"
