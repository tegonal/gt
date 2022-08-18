#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.1.0-SNAPSHOT
#
#######  Description  #############
#
#  'reset' command of gget: utility to reset (re-initialise gpg, pull files) for all or one previously defined remote
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # resets all defined remotes, which means for each remote in .gget
#    # - re-initialise gpg trust based on public keys defined in .gget/remotes/<remote>/public-keys/*.asc
#    # - pull files defined in .gget/remotes/<remote>/pulled
#    gget reset
#
#    # resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .gget/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .gget/remotes/tegonal-scripts/pulled
#    gget reset -r tegonal-scripts
#
#    # uses a custom working directory and resets the remote tegonal-scripts which means:
#    # - re-initialise gpg trust based on public keys defined in .github/.gget/remotes/tegonal-scripts/public-keys/*.asc
#    # - pull files defined in .github/.gget/remotes/tegonal-scripts/pulled
#    gget reset -r tegonal-scripts -w .github/.gget
#
###################################
set -euo pipefail
export GGET_VERSION='v0.2.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
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
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget_reset() {
	local defaultWorkingDir
	source "$dir_of_gget/shared-patterns.source.sh" || die "was not able to source shared-patterns.source.sh"

	local remote workingDir autoTrust
	# shellcheck disable=SC2034
	local -ar params=(
		remote "$remotePattern" '(optional) if set, only the remote with this name is reset, otherwise all are reset'
		workingDir "$workingDirPattern" "$workingDirParamDocu"
		autoTrust "$autoTrustPattern" "$autoTrustParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# reset the remote tegonal-scripts
			gget reset -r tegonal-scripts

			# resets all remotes
			gget reset

			# resets all remotes and imports gpg keys without manual consent
			gget reset --auto-trust true
		EOM
	)

	parseArguments params "$examples" "$GGET_VERSION" "$@"
	if ! [[ -v remote ]]; then remote=""; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	checkAllArgumentsSet params "$examples" "$GGET_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir")
	local -r workingDirAbsolute

	local -i success=0
	local -i errors=0

	function gget_reset_rePull() {
		local -r remote=$1
		local pulledTsv
		source "$dir_of_gget/paths.source.sh"
		if ! [[ -f $pulledTsv ]]; then
			logWarning "Looks like remote %s is broken or no file has been fetched so far, there is no pulled.tsv, skipping it" "$remote"
			return 0
		fi
		# start from line 2, i.e. skip the header in pulled.tsv
		tail -n +2 "$pulledTsv" >&5
		while read -u 6 -r entry; do
			local entryTag entryFile entryRelativePath
			setEntryVariables "$entry"
			local entryAbsolutePath parentDir
			entryAbsolutePath=$(readlink -m "$workingDirAbsolute/$entryRelativePath")
			parentDir=$(dirname "$entryAbsolutePath")
			if gget_pull -w "$workingDirAbsolute" -r "$remote" -t "$entryTag" -p "$entryFile" -d "$parentDir" --chop-path true --auto-trust "$autoTrust"; then
				((++success))
			else
				logError "could not fetch \033[0;36m%s\033[0m from remote %s" "$entryFile" "$remote"
				((++errors))
			fi
		done
	}

	function gget_reset_resetRemote() {
		local -r remote=$1

		local gpgDir pulledTsv
		source "$dir_of_gget/paths.source.sh"
		if [[ -d $gpgDir ]]; then
			deleteDirChmod777 "$gpgDir"
			logInfo "removed $gpgDir, going to re-pull files"
		else
			logInfo "$gpgDir does not exist, going to re-pull files"
		fi
		withCustomOutputInput 5 6 gget_reset_rePull "$remote"
	}

	function gget_reset_listAllRemotes() {
		gget_remote_list -w "$workingDirAbsolute" >&7
		local remote
		while read -u 8 -r remote; do
			gget_reset_resetRemote "$remote"
		done
	}

	if [[ -n $remote ]]; then
		gget_reset_resetRemote "$remote"
	else
		withCustomOutputInput 7 8 gget_reset_listAllRemotes
	fi

	if ((errors == 0)); then
		logSuccess "%s files reset successfully" "$success"
	else
		logWarning "%s files reset successfully, %s errors occurred, see above" "$success" "$errors"
		return 1
	fi
}

${__SOURCED__:+return}
gget_reset "$@"
