#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.6.0
#
#######  Description  #############
#
#  'reset' command of gget: utility to reset (re-initialise gpg, re-pull all files) for all or one previously defined remote
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # resets all defined remotes, which means for each remote in .gget
#    # - re-initialise gpg trust based on public keys defined in .gget/remotes/<remote>/public-keys/*.asc
#    # - pull files defined in .gget/remotes/<remote>/pulled.tsv
#    gget reset
#
#    # resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .gget/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .gget/remotes/tegonal-scripts/pulled.tsv
#    gget reset -r tegonal-scripts
#
#    # uses a custom working directory and resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .github/.gget/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .github/.gget/remotes/tegonal-scripts/pulled.tsv
#    gget reset -r tegonal-scripts -w .github/.gget
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GGET_VERSION='v0.6.0'

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
sourceOnce "$dir_of_gget/gget-re-pull.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget_reset_backToCurrentDir() {
	local -r currentDir=$1
	shift 1 || die "could not shift by 1"

	# revert side effect of cd
	cd "$currentDir"
}

function gget_reset() {
	local defaultWorkingDir unsecurePattern
	source "$dir_of_gget/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local remote workingDir
	# shellcheck disable=SC2034
	local -ar params=(
		remote "$remotePattern" '(optional) if set, only the remote with this name is reset, otherwise all are reset'
		workingDir "$workingDirPattern" "$workingDirParamDocu"
		gpgOnly "--gpg-only" '(optional) if set, then only the gpg keys are reset but the files are not re-pulled -- default: false'
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# reset the remote tegonal-scripts
			gget reset -r tegonal-scripts

			# resets all remotes
			gget reset

			# resets the gpg keys of all remotes without re-pulling the corresponding files
			gget reset --gpg-only true
		EOM
	)

	parseArguments params "$examples" "$GGET_VERSION" "$@"
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v gpgOnly ]]; then gpgOnly=false; fi
	exitIfNotAllArgumentsSet params "$examples" "$GGET_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	function gget_reset_resetRemote() {
		local -r remote=$1

		exitIfRemoteDirDoesNotExist "$workingDir" "$remote"

		local publicKeysDir gpgDir repo
		source "$dir_of_gget/paths.source.sh" || die "could not source paths.source.sh"
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
		# we partly undo this cd in gget_reset_backToCurrentDir. Yet, every script which would depend on
		# currentDir after this line can be influenced by this cd
		cd "$repo"

		# we want to expand $currentDir here and not when signal happens (as they might be out of scope)
		# shellcheck disable=SC2064
		trap "gget_reset_backToCurrentDir '$currentDir'" EXIT SIGINT

		local defaultBranch
		defaultBranch=$(determineDefaultBranch "$remote")
		if ! checkoutGgetDir "$remote" "$defaultBranch"; then
			die "no .gget directory defined in remote \033[0;36m%s\033[0m, cannot (re-)pull gpg keys" "$remote"
		fi

		if noAscInDir "$repo/.gget"; then
			logError "remote \033[0;36m%s\033[0m has a directory \033[0;36m.gget\033[0m but no GPG key ending in *.asc defined in it" "$remote"
			exitBecauseNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecurePattern"
		fi

		local -i numberOfImportedKeys=0
		function gget_reset_importKeyCallback() {
			((++numberOfImportedKeys))
		}

		importRemotesPulledPublicKeys "$workingDirAbsolute" "$remote" gget_reset_importKeyCallback

		if ((numberOfImportedKeys == 0)); then
			exitBecauseNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecurePattern"
		fi
		cd "$currentDir"
	}

	function gget_reset_allRemotes() {
		gget_remote_list -w "$workingDirAbsolute" >&7
		local remote
		while read -u 8 -r remote; do
			gget_reset_resetRemote "$remote"
		done
	}

	if [[ -n $remote ]]; then
		# we know that set -e is disabled for gget_reset_resetRemote due to ||
		#shellcheck disable=SC2310
		gget_reset_resetRemote "$remote" || die "could not remove gpg directory for remote %s, see above" "$remote"
		if [[ $gpgOnly != true ]]; then
			gget_re_pull -w "$workingDir" --only-missing false -r "$remote"
		fi
	else
		withCustomOutputInput 7 8 gget_reset_allRemotes || die "could not remove gpg directories, see above"
		if [[ $gpgOnly != true ]]; then
			gget_re_pull -w "$workingDir" --only-missing false
		fi
	fi
}

${__SOURCED__:+return}
gget_reset "$@"
