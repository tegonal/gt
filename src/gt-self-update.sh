#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.19.0
#######  Description  #############
#
#  'self-update' command of gt: utility to update gt
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # update gt to the latest version
#    gt self-update
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v0.19.0'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gt/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gt_self_update() {
	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local -r forcePattern='--force'

	local forceInstall
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ar params=(
		forceInstall "$forcePattern" "if set to true, then install.sh will be called even if gt is already on latest tag -- default false"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# updates gt to the latest tag
			gt self-update

			# updates gt to the latest tag and downloads the sources even if already on the latest
			gt self-update --force
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@"
	if ! [[ -v forceInstall ]]; then forceInstall="false"; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	local installDir
	installDir="$(readlink -m "$dir_of_gt/..")"
	local -r installDir

	if ! [[ -f "$installDir/install.sh" ]]; then
		die "looks like the previous installation is corrupt, there is no install.sh in %s\nPlease re-install gt according to:\nhttps://github.com/tegonal/gt#installation" "$installDir"
	fi

	if [[ -d "$installDir/.git" ]]; then
		# looks like it was an installation via git in this case we first check if there is a new version
		cd "$installDir" || die "could not cd to the installation directory of gt, see above"
		local currentBranch latestTag
		currentBranch=$(currentGitBranch)
		latestTag=$(latestRemoteTag)
		if [[ $currentBranch == "$latestTag" ]]; then
			logInfoWithoutNewline "latest version of gt (%s) is already installed" "$latestTag"
			if [[ $forceInstall != true ]]; then
				printf ", nothing to do in addition (specify %s true if you want to re-install)\n" "$forcePattern"
				return 0
			else
				printf ", but '%s true' was specified, going to re-install it\n" "$forcePattern"
			fi
		fi
		cd "$currentDir" || die "could not cd back to the current dir"
	else
		logInfo "looks like you did not install gt via install.sh (%s does not exist)" "$installDir/.git"
		if ! askYesOrNo "Do you want to run the following command to replace the current installation with the latest version:\ninstall.sh --directory \"%s\"" "$installDir"; then
			logInfo "aborted self update"
			return 1
		fi
	fi

	local tmpDir
	tmpDir=$(mktemp -d -t gt-install-XXXXXXXXXX)
	cp -r "$installDir" "$tmpDir/gt"
	cd "$tmpDir/gt" || die "could not cd to the tmpDir, see above"
	./install.sh --directory "$installDir"
}

${__SOURCED__:+return}
gt_self_update "$@"
