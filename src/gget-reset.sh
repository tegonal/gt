#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.6.0-SNAPSHOT
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
export GGET_VERSION='v0.5.0-SNAPSHOT'

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

function gget_reset() {
	local defaultWorkingDir
	source "$dir_of_gget/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

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
	exitIfNotAllArgumentsSet params "$examples" "$GGET_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	function gget_reset_resetRemote() {
		local -r remote=$1

		local gpgDir
		source "$dir_of_gget/paths.source.sh" || die "could not source paths.source.sh"
		if [[ -d $gpgDir ]]; then
			deleteDirChmod777 "$gpgDir"
			logInfo "removed $gpgDir"
		else
			logInfo "$gpgDir does not exist, not necessary to reset"
		fi
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
		gget_re_pull -w "$workingDir" --auto-trust "$autoTrust" --only-missing false -r "$remote"
	else
		withCustomOutputInput 7 8 gget_reset_allRemotes || die "could not remove gpg directories, see above"
		gget_re_pull -w "$workingDir" --auto-trust "$autoTrust" --only-missing false
	fi
}

${__SOURCED__:+return}
gget_reset "$@"
