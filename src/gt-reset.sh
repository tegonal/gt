#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.6.2
#######  Description  #############
#
#  'reset' command of gt: utility to reset (re-initialise gpg, re-pull all files) for all or one previously defined remote
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # resets all defined remotes, which means for each remote in .gt
#    # - re-initialise gpg trust based on public keys defined in .gt/remotes/<remote>/public-keys/*.asc
#    # - pull files defined in .gt/remotes/<remote>/pulled.tsv
#    gt reset
#
#    # resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .gt/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .gt/remotes/tegonal-scripts/pulled.tsv
#    gt reset -r tegonal-scripts
#
#    # only re-initialise gpg trust based on public keys defined in .gt/remotes/tegonal-scripts/public-keys/*.asc
#    gt reset -r tegonal-scripts --gpg-only true
#
#    # uses a custom working directory and resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .github/.gt/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .github/.gt/remotes/tegonal-scripts/pulled.tsv
#    gt reset -w .github/.gt -r tegonal-scripts
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export GT_VERSION='v1.6.2'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gt/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_gt/gt-pull.sh"
sourceOnce "$dir_of_gt/gt-remote.sh"
sourceOnce "$dir_of_gt/gt-re-pull.sh"
sourceOnce "$dir_of_gt/pulled-utils.sh"
sourceOnce "$dir_of_gt/utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gt_reset() {
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local remote workingDir gpgOnly
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ar params=(
		remote "$remoteParamPattern" '(optional) if set, only the remote with this name is reset, otherwise all are reset'
		gpgOnly "$gpgOnlyParamPattern" '(optional) if set to true, then only the gpg keys are reset but the files are not re-pulled -- default: false'
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# reset the remote tegonal-scripts
			gt reset -r tegonal-scripts

			# resets all remotes
			gt reset

			# resets the gpg keys of all remotes without re-pulling the corresponding files
			gt reset --gpg-only true
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@" || return $?
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v gpgOnly ]]; then gpgOnly=false; fi

	# before we report about missing arguments we check if the working directory exists and
	# if it is inside of the call location
	exitIfWorkingDirDoesNotExist "$workingDir"
	exitIfPathNamedIsOutsideOf "$workingDir" "working directory" "$currentDir"

	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	function gt_reset_resetRemote() {
		local -r remote=$1

		exitIfRemoteDirDoesNotExist "$workingDir" "$remote"
		exitIfRepoBrokenAndReInitIfAbsent "$workingDirAbsolute" "$remote"

		local publicKeysDir gpgDir repo pullArgsFile
		source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"
		if [[ -d $publicKeysDir ]]; then
			logInfo "Going to re-establish gpg trust in remote \033[0;36m%s\033[0m, removing %s" "$remote" "$publicKeysDir"
			deleteDirChmod777 "$publicKeysDir" || die "could not delete the public keys dir of remote \033[0;36m%s\033[0m" "$remote"
		else
			logInfo "%s does not exist, not necessary to reset" "$publicKeysDir"
		fi
		mkdir "$publicKeysDir" || die "was not able to create the public keys dir at %s" "$publicKeysDir"
		initialiseGpgDir "$gpgDir"

		local unsecureArgs
		if [[ -f $pullArgsFile ]]; then
			unsecureArgs=$(grep -E "(--unsecure|--unsecure-no-verification)\s*true" "$pullArgsFile")
		else
			unsecureArgs=""
		fi

		local defaultBranch
		defaultBranch=$(determineDefaultBranch "$workingDirAbsolute" "$remote")
		if ! checkoutGtDir "$workingDirAbsolute" "$remote" "$defaultBranch" "$defaultWorkingDir"; then
			if [[ -n $unsecureArgs ]]; then
				logWarning "no %s directory defined in remote \033[0;36m%s\033[0m which means no GPG key available, ignoring it because %s was specified in %s" "$defaultWorkingDir" "$remote" "$unsecureArgs" "$pullArgsFile"
				return 0
			else
				logError "remote \033[0;36m%s\033[0m has no directory \033[0;36m.gt\033[0m defined in branch \033[0;36m%s\033[0m, unable to fetch the GPG key(s)" "$remote" "$defaultBranch"
				return 1
			fi
		fi

		if ! [[ -f "$repo/$defaultWorkingDir/$signingKeyAsc" ]]; then
			if [[ -n $unsecureArgs ]]; then
				logWarning "remote \033[0;36m%s\033[0m has a directory \033[0;36m%s\033[0m but no %s in it. Ignoring it because %s was specified in %s" "$remote" "$defaultWorkingDir" "$signingKeyAsc" "$unsecureArgs" "$pullArgsFile"
				return 0
			else
				logError "remote \033[0;36m%s\033[0m has a directory \033[0;36m%s\033[0m but no %s in it." "$remote" "$defaultWorkingDir" "$signingKeyAsc"
				return 1
			fi
		fi

		local -i numberOfImportedKeys=0
		function gt_reset_importKeyCallback() {
			((++numberOfImportedKeys))
		}

		importRemotesPulledSigningKey "$workingDirAbsolute" "$remote" gt_reset_importKeyCallback

		if ((numberOfImportedKeys == 0)); then
			if [[ -n $unsecureArgs ]]; then
				logWarning "no GPG keys imported, ignoring it because %s true was specified" "$unsecureArgs"
				return 0
			else
				exitBecauseSigningKeyNotImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecureParamPatternLong" "$signingKeyAsc"
			fi
		fi

		logSuccess "re-established trust in remote \033[0;36m%s\033[0m" "$remote"
	}

	function gt_reset_allRemotes() {
		gt_remote_list_raw -w "$workingDirAbsolute" >&7
		local -i count=0
		local remote
		while read -u 8 -r remote; do
			gt_reset_resetRemote "$remote"
			((++count))
		done
		if ((count == 0)); then
			logInfo "Nothing to reset as no remote is defined yet.\nUse the \033[0;35mgt remote add ...\033[0m command to specify one -- for more info: gt remote add --help"
		fi
	}

	if [[ -n $remote ]]; then
		gt_reset_resetRemote "$remote" || die "could not remove gpg directory for remote \033[0;36m%s\033[0m, see above" "$remote"
		if [[ $gpgOnly != true ]]; then
			gt_re_pull -w "$workingDirAbsolute" --only-missing false -r "$remote"
		fi
	else
		withCustomOutputInput 7 8 gt_reset_allRemotes || die "could not remove gpg directories, see above"
		if [[ $gpgOnly != true ]]; then
			gt_re_pull -w "$workingDirAbsolute" --only-missing false
		fi
	fi
}

${__SOURCED__:+return}
gt_reset "$@"
