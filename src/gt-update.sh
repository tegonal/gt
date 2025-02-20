#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.2.0-SNAPSHOT
#######  Description  #############
#
#  'update' command of gt: utility to update already pulled files
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # updates all pulled files of all remotes to latest tag according to the tag-filter of the file
#    gt update
#
#    # updates all pulled files of remote tegonal-scripts to latest tag according to the tag-filter of the file
#    gt update -r tegonal-scripts
#
#    # updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0 if the tag-filter of the file matches,
#    # (i.e. a file with tag-filter v2.* would not be downgraded to v1.0.0).
#    # Side note, if no filter was specified during `gt pull`, then .* is used per default which includes all tags -- see
#    # pulled.tsv to see the current tagFilter in use per file
#    gt update -r tegonal-scripts -t v1.0.0
#
#    # lists the updatable files of remote tegonal-scripts
#    get update -r tegonal-scripts --list true
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v1.2.0-SNAPSHOT'

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

	local defaultWorkingDir remoteParamPatternLong workingDirParamPatternLong tagParamPatternLong pathParamPatternLong
	local pullDirParamPatternLong chopPathParamPatternLong targetFileNamePatternLong autoTrustParamPatternLong
	local tagFilterParamPatternLong listParamPatternLong
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local remote workingDir list autoTrust tag
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ar params=(
		remote "$remoteParamPattern" '(optional) if set, only the files of this remote are updated, otherwise all'
		tag "$tagParamPattern" "(optional) define from which tag files shall be pulled, only valid if remote via $remoteParamPattern is specified"
		list "$listParamPattern" "(optional) if set to true, then no files are updated and instead a list with updatable files including versions are output -- default: false"
		autoTrust "$autoTrustParamPattern" "$autoTrustParamDocu"
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
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

	parseArguments params "$examples" "$GT_VERSION" "$@" || return $?
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v tag ]]; then tag=""; fi
	if ! [[ -v list ]]; then list=false; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"
	exitIfArgIsNotBoolean "$list" "$listParamPatternLong"

	if [[ -n $tag && -z $remote ]]; then
		die "tag can only be defined if a remote is specified via %s" "$remoteParamPattern"
	fi

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	if [[ -n $tag ]] && ! (cd "$repo" && hasRemoteTag "$tag" "$remote" 2>/dev/null); then
		local majorVersion remoteTags filteredTags
		majorVersion=$(sed -E 's/^(v?[0-9]+)\..*/\1/' <<<"$tag")
		remoteTags=$(cd "$repo" && remoteTagsSorted "$remote" -r) || (logInfo >&2 "check your internet connection" && return 1) || return $?
		filteredTags=$(grep -E "^v?${majorVersion#v}" <<<"$remoteTags" || echo '')
		if [[ -n $filteredTags ]]; then
			die "remote %s does not have tag \033[0;36m%s\033[0m\nFollowing the available tags matching the same major version %s:\n%s" "$remote" "$tag" "$majorVersion" "$filteredTags"
		else
			die "remote %s does not have tag \033[0;36m%s\033[0m nor any tags matching the same major version %s\nFollowing the available tags:\n%s" "$remote" "$tag" "$majorVersion" "$remoteTags"
		fi
	fi

	local -i pulled=0
	local -i skipped=0
	local -i errors=0
	local -i updatable=0

	function gt_update_incrementError() {
		local -r entryFile=$1
		local -r remote=$2
		shift 2 || traceAndDie "could not shift by 2"
		logError "could not pull \033[0;36m%s\033[0m from remote %s" "$entryFile" "$remote"
		((++errors))
	}

	# shellcheck disable=SC2317   # called by name
	function gt_update_rePullInternal() {
		local -r remote=$1
		shift 1 || traceAndDie "could not shift by 1"

		local -a updateablePerRemote=()
		local previousTagFilter=""
		local previousLatestTag=""

		function gt_update_rePullInternal_callback() {
			local entryTag entryFile entryRelativePath localAbsolutePath entryTagFilter _entrySha512
			# shellcheck disable=SC2034   # is passed by name to parseFnArgs
			local -ra params=(entryTag entryFile entryRelativePath localAbsolutePath entryTagFilter _entrySha512)
			parseFnArgs params "$@"

			local entryTargetFileName
			entryTargetFileName=$(basename "$entryRelativePath")

			local tagToPull
			if [[ -n $tag ]]; then
				tagToPull="$tag"
				if ! grep -E "$entryTagFilter" >/dev/null <<<"$tagToPull"; then
					# if the given tag does not match the entryTagFilter for the specific file, then we ignore the entry
					((++skipped))
					return
				fi
			elif [[ "$previousTagFilter" == "$entryTagFilter" ]]; then
				# no need to determine latest tag again, if the entryTagFilter is the same as for the previous file
				tagToPull="$previousLatestTag"
			else
				reInitialiseGitDirIfDotGitNotPresent "$workingDirAbsolute" "$remote"
				tagToPull=$(latestRemoteTagIncludingChecks "$workingDirAbsolute" "$remote" "$entryTagFilter") || die "could not determine latest tag for remote %s with filter %s, see above" "$remote" "$entryTagFilter"
				previousLatestTag="$tagToPull"
				previousTagFilter="$entryTagFilter"
			fi

			#shellcheck disable=SC2310		# we know that set -e is disabled for gt_update_incrementError due to ||
			parentDir=$(dirname "$localAbsolutePath") || gt_update_incrementError "$entryFile" "$remote" || return

			if [[ $list == true ]]; then
				if [[ $entryTag != "$tagToPull" ]]; then
					updateablePerRemote+=("$entryTag" "$tagToPull" "$entryFile")
				fi
			else
				if gt_pull \
					"$workingDirParamPatternLong" "$workingDirAbsolute" \
					"$remoteParamPatternLong" "$remote" \
					"$tagParamPatternLong" "$tagToPull" \
					"$pathParamPatternLong" "$entryFile" \
					"$pullDirParamPatternLong" "$parentDir" \
					"$chopPathParamPatternLong" true \
					"$targetFileNamePatternLong" "$entryTargetFileName" \
					"$autoTrustParamPatternLong" "$autoTrust" \
					"$tagFilterParamPatternLong" "$entryTagFilter"; then
					((++pulled))
				else
					gt_update_incrementError "$entryFile" "$remote"
				fi
			fi
		}
		readPulledTsv "$workingDirAbsolute" "$remote" gt_update_rePullInternal_callback 5 6

		if [[ $list == true ]]; then
			local -r updatablePerRemoteLength="${#updateablePerRemote[@]}"
			if ((updatablePerRemoteLength > 0)); then
				((updatable += updatablePerRemoteLength))

				logInfo "following the updates for remote \033[0;36m%s\033[0m:\nOld\tNew\tFile" "$remote"
				for ((i = 0; i < updatablePerRemoteLength; i += 3)); do
					local entryTag="${updateablePerRemote[i]}"
					local tagToPull="${updateablePerRemote[i + 1]}"
					local entryFile="${updateablePerRemote[i + 2]}"
					printf "%s\t%s\t%s\n" "$entryTag" "$tagToPull" "$entryFile"
				done
			else
				logInfo "no new version available for the files of remote \033[0;36m%s\033[0m" "$remote"
			fi
			printf "\n"
		fi
	}

	function gt_update_rePullRemote() {
		local -r remote=$1
		shift 1 || traceAndDie "could not shift by 1"

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

	if [[ $list == true ]]; then
		if ((updatable == 0)); then
			logInfo "no updates available"
		else
			logInfo "%s updates available, see above." "$((updatable / 3))"
		fi
	else
		endTime=$(date +%s.%3N)
		elapsed=$(bc <<<"scale=3; $endTime - $startTime")
		if ((errors == 0)); then
			logSuccess "%s files updated in %s seconds (%s skipped)" "$pulled" "$elapsed" "$skipped"
		else
			logWarning "%s files updated in %s seconds (%s skipped), %s errors occurred, see above" "$pulled" "$elapsed" "$skipped" "$errors"
			return 1
		fi
	fi
}

${__SOURCED__:+return}
gt_update "$@"
