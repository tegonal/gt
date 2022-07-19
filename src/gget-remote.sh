#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.2.0-SNAPSHOT
#
#######  Description  #############
#
#  'remote' command of gget: utlity to manage gget remotes
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
#    gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts
#
#    # lists all existing remotes
#    gget remote list
#
#    # removes the remote tegonal-scripts again
#    gget remote remove -r tegonal-scripts
#
###################################
set -eu -o pipefail
export -x GGET_VERSION='v0.2.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	declare -r dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$dir_of_gget/../lib/tegonal-scripts/src")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_gget/utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget-remote-cleanup-remote-on-unexpected-exit() {
	# maybe we still show commands at this point due to unexpected exit, thus turn it of just in case
	{ set +x; } 2>/dev/null

	# shellcheck disable=SC2181
	if ! (($? == 0)) && [[ -d $1 ]]; then
		deleteDirChmod777 "$1"
	fi
}

function gget-remote() {
	source "$dir_of_gget/shared-patterns.source.sh"

	function gget-remote-add() {

		local remote url pullDir workingDir unsecure
		# shellcheck disable=SC2034
		local -ra params=(
			remote "$remotePattern" 'name to refer to this the remote repository'
			url '-u|--url' 'url of the remote repository'
			pullDir "$pullDirPattern" '(optional) directory into which files are pulled -- default: lib/<remote>'
			unsecure "$unsecurePattern" "(optional) if set to true, the remote does not need to have GPG key(s) defined at $defaultWorkingDir/*.asc -- default: false"
			workingDir "$workingDirPattern" "$workingDirParamDocu"
		)
		local -r examples=$(
			cat <<-EOM
				# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
				# uses the default location lib/tegonal-scripts for the files which will be pulled from this remote
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

				# uses a custom pull directory, files of the remote tegonal-scripts will now
				# be placed into scripts/lib/tegonal-scripts instead of default location lib/tegonal-scripts
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -d scripts/lib/tegonal-scripts

				# Does not complain if the remote does not provide a GPG key for verification (but still tries to fetch one)
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts --unsecure true

				# uses a custom working directory
				gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -w .github/$defaultWorkingDir
			EOM
		)
		parseArguments params "$examples" "$GGET_VERSION" "$@"
		if ! [[ -v pullDir ]]; then pullDir="lib/$remote"; fi
		if ! [[ -v unsecure ]]; then unsecure=false; fi
		if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
		checkAllArgumentsSet params "$examples" "$GGET_VERSION"

		# make directory paths absolute
		local -r workingDir=$(readlink -m "$workingDir")

		mkdir -p "$workingDir/remotes"

		local remoteDir publicKeysDir repo gpgDir
		source "$dir_of_gget/paths.source.sh"

		if [[ -f $remoteDir ]]; then
			returnDying "cannot create remote directory, there is a file at this location: %s" "$remoteDir"
		elif [[ -d $remoteDir ]]; then
			returnDying "remote \033[0;36m%s\033[0m already exists, remove with: gget remote remove %s" "$remote" "$remote"
		fi

		mkdir "$remoteDir" || returnDying "failed to create remote directory %s" "$remoteDir"

		# we want to expand $remoteDir here and not when EXIT happens (as $remoteDir might be out of scope)
		# shellcheck disable=SC2064
		trap "gget-remote-cleanup-remote-on-unexpected-exit '$remoteDir'" EXIT

		echo "--directory \"$pullDir\"" >"$remoteDir/pull.args"

		mkdir "$publicKeysDir"
		mkdir "$repo"
		mkdir "$gpgDir"
		chmod 700 "$gpgDir"

		cd "$repo"

		# show commands in output
		set -x
		git init
		git remote add "$remote" "$url"

		# we need to copy the git config away in order that one can commit it
		# this file will be used to restore the config for those who have not setup the remote on their machine
		cp "$repo/.git/config" "$remoteDir/gitconfig"

		local defaultBranch
		defaultBranch="$(git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"

		git fetch --depth 1 "$remote" "$defaultBranch"

		# don't show commands in output anymore
		{ set +x; } 2>/dev/null

		if ! git checkout "$remote/$defaultBranch" -- '.gget'; then
			if [[ $unsecure == true ]]; then
				logWarning "no GPG key found, ignoring it because %s true was specified" "$unsecurePattern"
				echo "$unsecurePattern true" >>"$workingDir/pull.args"
				return 0
			else
				logError "remote \033[0;36m%s\033[0m has no directory \033[0;36m.gget\033[0m defined in branch \033[0;36m%s\033[0m, unable to fetch the GPG key(s) -- you can disable this check via %s true" "$remote" "$defaultBranch" "$unsecurePattern"
				return 1
			fi
		fi

		if noAscInDir "$repo/.gget"; then
			if [[ $unsecure == true ]]; then
				logWarning "remote \033[0;36m%s\033[0m has a directory \033[0;36m.gget\033[0m but no GPG key ending in *.asc defined in it, ignoring it because %s true was specified" "$remote" "$unsecurePattern"
				echo "$unsecurePattern true" >>"$workingDir/pull.args"
				return 0
			else
				logError "remote \033[0;36m%s\033[0m has a directory \033[0;36m.gget\033[0m but no GPG key ending in *.asc defined in it -- you can disable this check via %s true" "$remote" "$unsecurePattern"
				return 1
			fi
		fi

		local -i numberOfImportedKeys=0

		function gget-remote-importGpgKeys() {
			findAscInDir "$repo/.gget" -print0 >&3

			echo ""
			while read -u 4 -r -d $'\0' file; do
				if importGpgKey "$gpgDir" "$file" --confirm=true; then
					mv "$file" "$publicKeysDir/"
					((++numberOfImportedKeys))
				else
					echo "deleting key $file"
					rm "$file"
				fi
			done
		}
		withOutput3Input4 gget-remote-importGpgKeys

		deleteDirChmod777 "$repo/.gget"

		if ((numberOfImportedKeys == 0)); then
			if [[ $unsecure == true ]]; then
				logWarning "no GPG keys imported, ignoring it because %s true was specified" "$unsecurePattern"
				return 0
			else
				errorNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecurePattern"
			fi
		fi

		gpg --homedir "$gpgDir" --list-sig
		logSuccess "remote \033[0;36m%s\033[0m was set up successfully; imported %s GPG key(s) for verification.\nYou are ready to pull files via:\ngget pull -r %s -t <VERSION> -p <PATH>" "$remote" "$numberOfImportedKeys" "$remote"
	}

	function gget-remote-list() {
		local workingDir
		# shellcheck disable=SC2034
		local -ra params=(
			workingDir "$workingDirPattern" "$workingDirParamDocu"
		)
		local -r examples=$(
			cat <<-EOM
				# lists all defined remotes in .gget
				gget remote list

				# uses a custom working directory
				gget remote list -w .github/.gget
			EOM
		)

		parseArguments params "$examples" "$GGET_VERSION" "$@"
		if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
		checkAllArgumentsSet params "$examples" "$GGET_VERSION"

		checkWorkingDirExists "$workingDir"

		local remotesDir
		local -r remote="not really a remote but paths.source.sh requires it, hence we set it here"
		source "$dir_of_gget/paths.source.sh"

		cd "$remotesDir"
		local output
		output="$(find . -maxdepth 1 -type d -not -path "." | cut -c 3-)"
		if [[ $output == "" ]]; then
			logInfo "No remote define yet."
			echo "To add one, use: gget remote add ..."
			echo "Following the corresponding documentation of \`gget remote add\`:"
			gget-remote-add "--help"
		else
			echo "$output"
		fi
	}

	function gget-remote-remove() {
		local workingDir
		# shellcheck disable=SC2034
		local -ra params=(
			remote "$remotePattern" 'define the name of the remote which shall be removed'
			workingDir "$workingDirPattern" "$workingDirParamDocu"
		)
		local -r examples=$(
			cat <<-EOM
				# removes the remote tegonal-scripts
				gget remote remove -r tegonal-scripts

				# uses a custom working directory
				gget remote remove -r tegonal-scripts -w .github/.gget
			EOM
		)

		parseArguments params "$examples" "$GGET_VERSION" "$@"
		if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
		checkAllArgumentsSet params "$examples" "$GGET_VERSION"

		checkWorkingDirExists "$workingDir"

		local remoteDir
		source "$dir_of_gget/paths.source.sh"

		if [[ -f $remoteDir ]]; then
			returnDying "cannot delete remote \033[0;36m%s\033[0m, looks like it is broken there is a file at this location: %s" "$remote" "$remoteDir"
		elif ! [[ -d $remoteDir ]]; then
			logError "remote \033[0;36m%s\033[0m does not exist, check for typos.\nFollowing the remotes which exist:" "$remote"
			gget-remote-list -w "$workingDir"
			return 9
		fi

		deleteDirChmod777 "$remoteDir"
		logSuccess "removed remote \033[0;36m%s\033[0m" "$remote"
	}

	if (($# < 1)); then
		logError "At least one parameter needs to be passed to \`gget remote\`\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
		echo >&2 '1. command     one of: add, remove, list'
		echo >&2 '2... args...   command specific arguments'
		exit 9
	fi

	declare command=$1
	shift
	if [[ "$command" =~ ^(add|remove|list)$ ]]; then
		"gget-remote-$command" "$@"
	elif [[ "$command" == "--help" ]]; then
		cat <<-EOM
			Use one of the following commands:
			add      add a remote
			remove   remove a remote
			list     list all existing remotes
		EOM
	else
		returnDying "unknown command \033[0;36m%s\033[0m, expected one of add, list, remove -- as in gget remote list" "$command"
	fi
}

${__SOURCED__:+return}
gget-remote "$@"
