#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.13.0-SNAPSHOT
#
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
#    # uses a custom working directory and resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .github/.gt/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .github/.gt/remotes/tegonal-scripts/pulled.tsv
#    gt reset -r tegonal-scripts -w .github/.gt
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v0.13.0-SNAPSHOT'

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
sourceOnce "$dir_of_gt/gt-re-pull.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gt_reset_backToCurrentDir() {
	local -r currentDir=$1
	shift 1 || die "could not shift by 1"

	# revert side effect of cd
	cd "$currentDir"
}

function gt_reset() {
	local defaultWorkingDir unsecurePattern
	source "$dir_of_gt/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local remote workingDir
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ar params=(
		remote "$remotePattern" '(optional) if set, only the remote with this name is reset, otherwise all are reset'
		workingDir "$workingDirPattern" "$workingDirParamDocu"
		gpgOnly "--gpg-only" '(optional) if set, then only the gpg keys are reset but the files are not re-pulled -- default: false'
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

	parseArguments params "$examples" "$GT_VERSION" "$@"
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v gpgOnly ]]; then gpgOnly=false; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	function gt_reset_resetRemote() {
		local -r remote=$1

		exitIfRemoteDirDoesNotExist "$workingDir" "$remote"
		exitIfRepoBrokenAndReInitIfAbsent "$workingDirAbsolute" "$remote"

		local publicKeysDir gpgDir repo
		source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"
		if [[ -d $publicKeysDir ]]; then
			logInfo "Going to re-establish gpg trust, removing %s" "$publicKeysDir"
			deleteDirChmod777 "$publicKeysDir" || die "could not delete the public keys dir of remote \033[0;36m%s\033[0m" "$remote"
		else
			logInfo "%s does not exist, not necessary to reset" "$publicKeysDir"
		fi
		mkdir "$publicKeysDir" || die "was not able to create the public keys dir at %s" "$publicKeysDir"
		initialiseGpgDir "$gpgDir"

		# can be a problematic side effect, leaving as note here in case we run into issues at some point
		# alternatively we could use `git -C "$repo"` for every git command
		# we partly undo this cd in gt_reset_backToCurrentDir. Yet, every script which would depend on
		# currentDir after this line can be influenced by this cd
		cd "$repo"

		# we want to expand $currentDir here and not when signal happens (as they might be out of scope)
		# shellcheck disable=SC2064
		trap "gt_reset_backToCurrentDir '$currentDir'" EXIT SIGINT

		local defaultBranch
		defaultBranch=$(determineDefaultBranch "$remote")
		if ! checkoutGtDir "$remote" "$defaultBranch"; then
			die "no .gt directory defined in remote \033[0;36m%s\033[0m, cannot (re-)pull gpg keys" "$remote"
		fi

		if noAscInDir "$repo/.gt"; then
			logError "remote \033[0;36m%s\033[0m has a directory \033[0;36m.gt\033[0m but no GPG key ending in *.asc defined in it" "$remote"
			exitBecauseNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecurePattern"
		fi

		local -i numberOfImportedKeys=0
		function gt_reset_importKeyCallback() {
			((++numberOfImportedKeys))
		}

		importRemotesPulledPublicKeys "$workingDirAbsolute" "$remote" gt_reset_importKeyCallback

		if ((numberOfImportedKeys == 0)); then
			exitBecauseNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecurePattern"
		fi
		cd "$currentDir"
		logSuccess "re-established trust with remote \033[0;36m%s\033[0m" "$remote"
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
		#shellcheck disable=SC2310		# we know that set -e is disabled for gt_reset_resetRemote due to ||
		gt_reset_resetRemote "$remote" || die "could not remove gpg directory for remote %s, see above" "$remote"
		if [[ $gpgOnly != true ]]; then
			gt_re_pull -w "$workingDir" --only-missing false -r "$remote"
		fi
	else
		withCustomOutputInput 7 8 gt_reset_allRemotes || die "could not remove gpg directories, see above"
		if [[ $gpgOnly != true ]]; then
			gt_re_pull -w "$workingDir" --only-missing false
		fi
	fi
}

${__SOURCED__:+return}
gt_reset "$@"
