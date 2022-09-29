#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.8.0
#
#######  Description  #############
#
#  'self-update' command of gget: utility to update gget
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # update gget to the latest version
#    gget self-update
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GGET_VERSION='v0.8.0'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gget/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget_self_update() {
	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local -r forcePattern='--force'

	local forceInstall
	# shellcheck disable=SC2034
	local -ar params=(
		forceInstall "$forcePattern" "if set to true, then install.sh will be called even if gget is already on latest tag"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# updates gget to the latest tag
			gget self-update

			# updates gget to the latest tag and downloads the sources even if already on the latest
			gget self-update --force
		EOM
	)

	parseArguments params "$examples" "$GGET_VERSION" "$@"
	# shellcheck disable=SC2034
	if ! [[ -v forceInstall ]]; then forceInstall="false"; fi
	exitIfNotAllArgumentsSet params "$examples" "$GGET_VERSION"

	local installDir
	installDir="$(readlink -m "$dir_of_gget/..")"
	local -r installDir

	if ! [[ -f "$installDir/install.sh" ]]; then
		die "looks like the previous installation is corrupt, there is no install.sh in %s\nPlease re-install gget according to:\nhttps://github.com/tegonal/gget#installation" "$installDir"
	fi

	if [[ -d "$installDir/.git" ]]; then
		# looks like it was an installation via git in this case we first check if there is a new version
		cd "$installDir" || die "could not cd to the installation directory of gget, see above"
		local currentBranch latestTag
		currentBranch=$(currentGitBranch)
		latestTag=$(latestRemoteTag)
		if [[ $currentBranch == "$latestTag" ]]; then
			logInfoWithoutNewline "latest version of gget (%s) is already installed" "$latestTag"
			if [[ $forceInstall != true ]]; then
				printf ", nothing to do in addition (specify %s true if you want to re-install)\n" "$forcePattern"
				return 0
			else
				printf ", but '%s true' was specified, going to re-install it\n" "$forcePattern"
			fi
		fi
		cd "$currentDir" || die "could not cd back to the current dir"
	else
		logInfo "looks like you did not install gget via install.sh (%s does not exist)" "$installDir/.git"
		if ! askYesOrNo "Do you want to run the following command to replace the current installation with the latest version:\ninstall.sh --directory \"%s\"" "$installDir"; then
			logInfo "aborted self update"
			return 1
		fi
	fi

	local tmpDir
	tmpDir=$(mktemp -d -t gget-install-XXXXXXXXXX)
	cp -r "$installDir" "$tmpDir/gget"
	cd "$tmpDir/gget" || die "could not cd to the tmpDir, see above"
	./install.sh --directory "$installDir"
}

${__SOURCED__:+return}
gget_self_update "$@"
