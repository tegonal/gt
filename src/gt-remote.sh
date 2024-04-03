#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.17.4
#######  Description  #############
#
#  'remote' command of gt: utility to manage gt remotes
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
#    gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts
#
#    # lists all existing remotes
#    gt remote list
#
#    # removes the remote tegonal-scripts again
#    gt remote remove -r tegonal-scripts
#
###################################
set -eu -o pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v0.17.4'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_gt/utils.sh"
sourceOnce "$dir_of_gt/pulled-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-commands.sh"

function gt_remote_cleanupRemoteOnUnexpectedExit() {
	local -r result=$?

	local -r remoteDir=$1
	local -r currentDir=$2
	shift 2 || die "could not shift by 2"

	if ! ((result == 0)) && [[ -d $remoteDir ]]; then
		deleteDirChmod777 "$remoteDir"
	fi
}

function gt_remote_add() {
	source "$dir_of_gt/common-constants.source.sh" || die "could not source common-constants.source.sh"

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local remote url pullDir unsecure workingDir
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		remote "$remoteParamPattern" 'name to refer to this the remote repository'
		url '-u|--url' 'url of the remote repository'
		pullDir "$pullDirParamPattern" '(optional) directory into which files are pulled -- default: lib/<remote>'
		unsecure "$unsecureParamPattern" "(optional) if set to true, the remote does not need to have GPG key(s) defined at $defaultWorkingDir/*.asc -- default: false"
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
			# uses the default location lib/tegonal-scripts for the files which will be pulled from this remote
			gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

			# uses a custom pull directory, files of the remote tegonal-scripts will now
			# be placed into scripts/lib/tegonal-scripts instead of default location lib/tegonal-scripts
			gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -d scripts/lib/tegonal-scripts

			# Does not complain if the remote does not provide a GPG key for verification (but still tries to fetch one)
			gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts --unsecure true

			# uses a custom working directory
			gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -w .github/$defaultWorkingDir
		EOM
	)
	parseArguments params "$examples" "$GT_VERSION" "$@"
	if ! [[ -v pullDir ]]; then pullDir="lib/${remote-'remote-not-defined'}"; fi
	if ! [[ -v unsecure ]]; then unsecure=false; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	if ! checkWorkingDirExists "$workingDirAbsolute"; then
		if askYesOrNo "Shall I create the work directory for you and continue?"; then
			mkdir -p "$workingDirAbsolute" || die "was not able to create the workingDir %s" "$workingDirAbsolute"
		else
			exit 9
		fi
	fi

	mkdir -p "$workingDirAbsolute/remotes" || die "was not able to create directory %s" "$workingDirAbsolute/remotes"

	local remoteDir publicKeysDir repo gpgDir pullArgsFile gitconfig
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	if [[ -f $remoteDir ]]; then
		die "cannot create remote directory, there is a file at this location: %s" "$remoteDir"
	elif [[ -d $remoteDir ]]; then
		returnDying "remote \033[0;36m%s\033[0m already exists, remove with: gt remote remove %s" "$remote" "$remote" || return $?
	fi

	mkdir "$remoteDir" || die "failed to create remote directory %s" "$remoteDir"

	# we want to expand $remoteDir and $currentDir here and not when signal happens (as they might be out of scope)
	# shellcheck disable=SC2064
	trap "gt_remote_cleanupRemoteOnUnexpectedExit '$remoteDir' '$currentDir'" EXIT SIGINT

	echo "--directory \"$pullDir\"" >"$pullArgsFile" || logWarning "was not able to write the pull directory %s into %s\nPlease do it manually or use --directory when using 'gt pull' with the remote %s" "$pullDir" "$pullArgsFile" "$remote"

	mkdir "$publicKeysDir" || die "was not able to create the public keys dir at %s" "$publicKeysDir"
	initialiseGpgDir "$gpgDir"
	initialiseGitDir "$workingDir" "$remote"

	git -C "$repo" remote add "$remote" "$url"

	# we need to copy the git config away in order that one can commit it
	# this file will be used to restore the config for those who have not setup the remote on their machine
	cp "$repo/.git/config" "$gitconfig"

	local defaultBranch
	defaultBranch=$(determineDefaultBranch "$workingDirAbsolute" "$remote")

	if ! checkoutGtDir "$workingDirAbsolute" "$remote" "$defaultBranch"; then
		if [[ $unsecure == true ]]; then
			logWarning "no .gt directory defined in remote \033[0;36m%s\033[0m which means no GPG key available, ignoring it because %s true was specified" "$remote" "$unsecureParamPattern"
			echo "$unsecureParamPattern true" >>"$pullArgsFile" || logWarning "was not able to write '%s true' into %s, please do it manually" "$unsecureParamPattern" "$pullArgsFile"
			return 0
		else
			logError "remote \033[0;36m%s\033[0m has no directory \033[0;36m.gt\033[0m defined in branch \033[0;36m%s\033[0m, unable to fetch the GPG key(s) -- you can disable this check via %s true" "$remote" "$defaultBranch" "$unsecureParamPattern"
			return 1
		fi
	fi

	if noAscInDir "$repo/.gt"; then
		if [[ $unsecure == true ]]; then
			logWarning "remote \033[0;36m%s\033[0m has a directory \033[0;36m.gt\033[0m but no GPG key ending in *.asc defined in it, ignoring it because %s true was specified" "$remote" "$unsecureParamPattern"
			echo "$unsecureParamPattern true" >>"$workingDirAbsolute/pull.args"
			return 0
		else
			logError "remote \033[0;36m%s\033[0m has a directory \033[0;36m.gt\033[0m but no GPG key ending in *.asc defined in it -- you can disable this check via %s true" "$remote" "$unsecureParamPattern"
			return 1
		fi
	fi

	local -i numberOfImportedKeys=0
	# shellcheck disable=SC2317   # called by name
	function gt_remote_importKeyCallback() {
		((++numberOfImportedKeys))
	}

	importRemotesPulledPublicKeys "$workingDirAbsolute" "$remote" gt_remote_importKeyCallback

	if ((numberOfImportedKeys == 0)); then
		if [[ $unsecure == true ]]; then
			logWarning "no GPG keys imported, ignoring it because %s true was specified" "$unsecureParamPattern"
			return 0
		else
			exitBecauseNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecureParamPattern"
		fi
	fi

	gpg --homedir "$gpgDir" --list-sig || die "was not able to list the gpg keys, looks like a broken setup, aborting"
	logSuccess "remote \033[0;36m%s\033[0m was set up successfully; imported %s GPG key(s) for verification.\nYou are ready to pull files via:\ngt pull -r %s -p <PATH>" "$remote" "$numberOfImportedKeys" "$remote"
}

function gt_remote_list_raw() {
	source "$dir_of_gt/common-constants.source.sh"

	local workingDir
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# lists all defined remotes in .gt
			gt remote list

			# uses a custom working directory
			gt remote list -w .github/.gt
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@"
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local remotesDir
	local -r remote="not really a remote but paths.source.sh requires it, hence we set it here but don't use it afterwards"
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	local cutLength
	cutLength=$((${#remotesDir} + 2))

	[[ -d $remotesDir ]] && find "$remotesDir" -maxdepth 1 -type d -not -path "$remotesDir" | cut -c "$cutLength"- || echo ""
}

function gt_remote_list() {
	local output
	output=$(gt_remote_list_raw "$@")
	if [[ $output == "" ]]; then
		logInfo "No remote defined yet."
		echo ""
		printf "To add one, use: \033[0;35mgt remote add ...\033[0m\n"
		echo "Following the output of calling \`gt remote add --help\`:"
		echo ""
		gt_remote_add "--help"
	else
		echo "$output"
	fi
}

function gt_remote_remove() {
	source "$dir_of_gt/common-constants.source.sh" || die "could not source common-constants.source.sh"

	local remote workingDir
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		remote "$remoteParamPattern" 'define the name of the remote which shall be removed'
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
		deletePulledFiles "--delete-pulled-files" "(optional) if set, then all files defined in the remote's pulled.tsv are deleted as well"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# removes the remote tegonal-scripts
			gt remote remove -r tegonal-scripts

			# uses a custom working directory
			gt remote remove -r tegonal-scripts -w .github/.gt
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@"
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v deletePulledFiles ]]; then deletePulledFiles="false"; fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	exitIfWorkingDirDoesNotExist "$workingDir"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local remoteDir pulledTsv pullHookFile
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	if [[ -f $remoteDir ]]; then
		logError "cannot delete remote \033[0;36m%s\033[0m, looks like it is broken there is a file at this location: %s" "$remote" "$remoteDir"
		return 1
	else
		exitIfRemoteDirDoesNotExist "$workingDirAbsolute" "$remote"
	fi

	if [[ -f $pullHookFile ]]; then
		logWarning "detected a pull-hook.sh in the remote %s, you might want to move it away first." "$remote"
		if ! askYesOrNo "shall I continue and delete it as well?"; then
			logInfo "removing remote \033[0;36m%s\033[0m aborted" "$remote"
			exit 10
		fi
	fi

  # shellcheck disable=SC2317   # called by name
	function gt_remote_remove_read() {
		local -i numberOfDeletedFiles=0

		function gt_remote_remove_readCallback() {
			local _entryTag _entryFile _entryRelativePath entryAbsolutePath
			# shellcheck disable=SC2034   # is passed by name to parseFnArgs
			local -ra params=(_entryTag _entryFile _entryRelativePath entryAbsolutePath)
			parseFnArgs params "$@"
			rm "$entryAbsolutePath"
			((++numberOfDeletedFiles))
		}

		readPulledTsv "$workingDirAbsolute" "$remote" gt_remote_remove_readCallback 5 6
		logInfo "deleted %s pulled files" "$numberOfDeletedFiles"
	}

	if [[ -f $pulledTsv ]]; then
		if [[ $deletePulledFiles != true ]]; then
			logInfo "detected a pulled.tsv in the remote %s. You might want to pass '--delete-pulled-files true' in case you want to delete all files" "$remote"
			if askYesOrNo "Shall I abort? If you don't choose y, then I will go on and delete the remote without deleting the pulled files as defined in pulled.tsv"; then
				logInfo "removing remote \033[0;36m%s\033[0m aborted" "$remote"
				exit 10
			fi
		else
			withCustomOutputInput 5 6 gt_remote_remove_read
		fi
	fi

	deleteDirChmod777 "$remoteDir" || die "was not able to delete remoteDir %s" "$remoteDir"
	logSuccess "removed remote \033[0;36m%s\033[0m" "$remote"
}

function gt_remote_source() {
	# no op the command functions are already in this file
	true
}

function gt_remote() {
	# shellcheck disable=SC2034   # is passed by name to parseCommands
	local -ra commands=(
		add 'add a remote'
		remove 'remove a remote'
		list 'list all remotes'
	)
	parseCommands commands "$GT_VERSION" gt_remote_source gt_remote_ "$@"
}

${__SOURCED__:+return}
gt_remote "$@"
