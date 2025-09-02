#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.5.0-SNAPSHOT
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
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export GT_VERSION='v1.5.0-SNAPSHOT'

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
	if ! ((result == 0)) && [[ -d $remoteDir ]]; then
		if [[ -d $remoteDir ]]; then
			# delete the remoteDir and its content
			deleteDirChmod777 "$remoteDir"
		fi
		# re-add so that one can still establish trust manually
		mkdir "$remoteDir"
	fi
}

function gt_remote_add() {
	local pullDirParamPatternLong unsecureParamPatternLong tagFilterParamPatternLong
	local workingDirParamPatternLong remoteParamPatternLong signingKeyAsc
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local remote url pullDir unsecure workingDir tagFilter
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		remote "$remoteParamPattern" 'name identifying this remote'
		url '-u|--url' 'url of the remote repository'
		pullDir "$pullDirParamPattern" '(optional) directory into which files are pulled -- default: lib/<remote>'
		tagFilter "$tagFilterParamPattern" "$tagFilterParamDocu"
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

			# defines a tag-filter which is used when determining the latest version (in \`gt pull\` and in \`gt update\`)
			# this filter would for instance not match a version 2.0.0-RC1 and hence \`gt update\` would ignore it.
			gt remote add -r tegonal-scripts --tag-filter "^v[0-9]+\.[0-9]+\.[0-9]+$"

			# Does not complain if the remote does not provide a GPG key for verification (but still tries to fetch one)
			gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts --unsecure true

			# uses a custom working directory
			gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -w .github/$defaultWorkingDir
		EOM
	)
	parseArguments params "$examples" "$GT_VERSION" "$@" || return $?
	if ! [[ -v pullDir ]]; then pullDir="lib/${remote-'remote-not-defined'}"; fi
	if ! [[ -v unsecure ]]; then unsecure=false; fi
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v tagFilter ]]; then tagFilter=".*"; fi

	# before we report about missing arguments we check if the working directory is inside of the call location
	exitIfPathNamedIsOutsideOf "$workingDir" "working directory" "$currentDir"
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	local -r remoteIdentifierRegex="^[a-zA-Z0-9_-]+$"
	if ! [[ $remote =~ $remoteIdentifierRegex ]]; then
		die "remote names need to match the regex \033[0;36m%s\033[0m given %s" "$remoteIdentifierRegex" "$remote"
	fi

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	if ! checkWorkingDirExists "$workingDirAbsolute"; then
		if askYesOrNo >&2 "Shall I create the work directory for you and continue?"; then
			mkdir -p "$workingDirAbsolute" || die "was not able to create the workingDir %s" "$workingDirAbsolute"
			local gitIgnore="$currentDir/.gitignore"
			if [[ -f "$gitIgnore" ]] && ! grep "$workingDir/" "$gitIgnore"; then
				if askYesOrNo >&2 "Shall I add gt specific ignore patterns to %s" "$gitIgnore"; then
					printf "\n# gt (https://github.com/tegonal/gt)\n%s/**/repo\n%s/**/gpg\n" "$workingDir" "$workingDir" >>"$gitIgnore" || logWarning "was not able to write gpg ignore patterns to %s, please add them manually" "$gitIgnore"
				fi
			fi
		else
			exit 9
		fi
	fi

	mkdir -p "$workingDirAbsolute/remotes" || die "was not able to create directory %s" "$workingDirAbsolute/remotes"

	local remoteDir publicKeysDir repo gpgDir pullArgsFile gitconfig
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	if [[ -f $remoteDir ]]; then
		die "cannot create remote directory, there is a file at this location: %s" "$remoteDir"
	elif [[ -d $remoteDir ]]; then
		if [[ -f "$remoteDir/pulled.tsv" ]]; then
			returnDying "remote \033[0;36m%s\033[0m already exists with pulled files" "$remote" || return $?
		else
			logError "remote \033[0;36m%s\033[0m already exists but without pulled files" "$remote"
			if askYesOrNo >&2 "Shall I remove the remote for you and continue?"; then
				gt_remote_remove "$workingDirParamPatternLong" "$workingDirAbsolute" "$remoteParamPatternLong" "$remote"
			else
				return 1
			fi
		fi

	fi

	mkdir "$remoteDir" || die "failed to create remote directory %s" "$remoteDir"

	# we want to expand $remoteDir and $currentDir here and not when signal happens (as they might be out of scope)
	# shellcheck disable=SC2064
	trap "gt_remote_cleanupRemoteOnUnexpectedExit '$remoteDir'" EXIT

	echo "$pullDirParamPatternLong \"$pullDir\"" >"$pullArgsFile" || logWarningCouldNotWritePullArgs "the pull directory" "$pullDir" "$pullArgsFile" "$pullDirParamPatternLong" "$remote"

	if [[ $tagFilter != ".*" ]]; then
		echo "$tagFilterParamPattern \"$tagFilter\"" >>"$pullArgsFile" || logWarningCouldNotWritePullArgs "the tag filter" "$tagFilter" "$pullArgsFile" "$tagFilterParamPatternLong" "$remote"
	fi

	mkdir "$publicKeysDir" || die "was not able to create the public keys dir at %s" "$publicKeysDir"
	initialiseGpgDir "$gpgDir"
	initialiseGitDir "$workingDir" "$remote"

	git -C "$repo" remote add "$remote" "$url"

	# we need to copy the git config away in order that one can commit it
	# this file will be used to restore the config for those who have not setup the remote on their machine
	cp "$repo/.git/config" "$gitconfig"

	local defaultBranch
	defaultBranch=$(determineDefaultBranch "$workingDirAbsolute" "$remote")

	if ! checkoutGtDir "$workingDirAbsolute" "$remote" "$defaultBranch" "$defaultWorkingDir"; then
		if [[ $unsecure == true ]]; then
			logWarning "no %s directory defined in remote \033[0;36m%s\033[0m which means no GPG key available, ignoring it because %s true was specified" "$defaultWorkingDir" "$remote" "$unsecureParamPatternLong"
			echo "$unsecureParamPatternLong true" >>"$pullArgsFile" || logWarningCouldNotWritePullArgs "$unsecureParamPatternLong" "true" "$pullArgsFile" "$remote"
			return 0
		else
			logError "remote \033[0;36m%s\033[0m has no directory \033[0;36m.gt\033[0m defined in branch \033[0;36m%s\033[0m, unable to fetch the GPG key(s) -- you can disable this check via %s true" "$remote" "$defaultBranch" "$unsecureParamPatternLong"
			return 1
		fi
	fi

	if ! [[ -f "$repo/$defaultWorkingDir/$signingKeyAsc" ]]; then
		if [[ $unsecure == true ]]; then
			logWarning "remote \033[0;36m%s\033[0m has a directory \033[0;36m%s\033[0m but no %s in it. Ignoring it because %s true was specified" "$remote" "$defaultWorkingDir" "$signingKeyAsc" "$unsecureParamPatternLong"
			echo "$unsecureParamPatternLong true" >>"$pullArgsFile" || logWarningCouldNotWritePullArgs "$unsecureParamPatternLong" "true" "$pullArgsFile" "$remote"
			return 0
		else
			logError "remote \033[0;36m%s\033[0m has a directory \033[0;36m%s\033[0m but no %s in it -- you can disable this check via %s true" "$remote" "$defaultWorkingDir" "$signingKeyAsc" "$unsecureParamPatternLong"
			return 1
		fi
	fi

	# end of checks, can start importing keys

	local -i numberOfImportedKeys=0
	# shellcheck disable=SC2329   # called by name
	# shellcheck disable=SC2317   # for intellij
	function gt_remote_importKeyCallback() {
		((++numberOfImportedKeys))
	}

	importRemotesPulledSigningKey "$workingDirAbsolute" "$remote" gt_remote_importKeyCallback

	if ((numberOfImportedKeys == 0)); then
		if [[ $unsecure == true ]]; then
			logWarning "no GPG keys imported, ignoring it because %s true was specified" "$unsecureParamPatternLong"
			return 0
		else
			exitBecauseSigningKeyNotImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecureParamPatternLong" "$signingKeyAsc"
		fi
	fi

	gpg --homedir "$gpgDir" --list-sig || die "was not able to list the gpg keys, looks like a broken setup, aborting"
	logSuccess "remote \033[0;36m%s\033[0m was set up successfully; imported %s GPG key(s) for verification.\nYou are ready to pull files via:\ngt pull -r %s -p <PATH>" "$remote" "$numberOfImportedKeys" "$remote"
}

function gt_remote_list_raw() {
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

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

	parseArguments params "$examples" "$GT_VERSION" "$@" || return $?
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi

	# before we report about missing arguments we check if the working directory exists and
	# if it is inside of the call location
	exitIfWorkingDirDoesNotExist "$workingDir"
	exitIfPathNamedIsOutsideOf "$workingDir" "working directory" "$currentDir"

	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local remotesDir
	local -r remote="not really a remote but paths.source.sh requires it, hence we set it here but don't use it afterwards"
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	local cutLength
	cutLength=$((${#remotesDir} + 2))

	[[ -d $remotesDir ]] && find "$remotesDir" -maxdepth 1 -type d -not -path "$remotesDir" | cut -c "$cutLength"- | sort || echo ""
}

function gt_remote_list() {
	local output
	# shellcheck disable=SC2310 	# we are aware of that || will disable set -e, that's what we want
	output=$(gt_remote_list_raw "$@") || [[ $? -eq 99 ]] # ignore if user used --help (returns 99), fail otherwise
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
	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local remote workingDir deletePulledFiles
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		remote "$remoteParamPattern" 'define the name of the remote which shall be removed'
		deletePulledFiles "--delete-pulled-files" "(optional) if set to true, then all files defined in the remote's pulled.tsv are deleted as well -- default: false"
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# removes the remote tegonal-scripts (but keeps already pulled files)
			gt remote remove -r tegonal-scripts

			# removes the remote tegonal-scripts and all pulled files
			gt remote remove -r tegonal-scripts --delete-pulled-files true

			# uses a custom working directory
			gt remote remove -r tegonal-scripts -w .github/$defaultWorkingDir
		EOM
	)

	parseArguments params "$examples" "$GT_VERSION" "$@" || return $?
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi
	if ! [[ -v deletePulledFiles ]]; then deletePulledFiles="false"; fi

	# before we report about missing arguments we check if the working directory exists and
	# if it is inside of the call location
	exitIfWorkingDirDoesNotExist "$workingDir"
	exitIfPathNamedIsOutsideOf "$workingDir" "working directory" "$currentDir"

	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	local workingDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	local -r workingDirAbsolute

	local remoteDir pulledTsv pullHookFile
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

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

	# shellcheck disable=SC2329   # called by name
	# shellcheck disable=SC2317   # for intellij
	function gt_remote_remove_read() {
		local -i numberOfDeletedFiles=0

		function gt_remote_remove_readCallback() {
			local _entryTag _entryFile _entryRelativePath entryAbsolutePath _entryTagFilter _entrySha512
			# shellcheck disable=SC2034   # is passed by name to parseFnArgs
			local -ra params=(_entryTag _entryFile _entryRelativePath entryAbsolutePath _entryTagFilter _entrySha512)
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
