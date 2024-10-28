#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.1.0-SNAPSHOT
#######  Description  #############
#
#  'pull' command of gt: utility to pull files from a previously defined git remote repository
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
#    # in version v0.1.0 (i.e. tag v0.1.0 is used)
#    # into the default directory of this remote
#    gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh
#
#    # pull the directory src/utility/ from remote tegonal-scripts
#    # in version v0.1.0 (i.e. tag v0.1.0 is used)
#    gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/
#
#    # pull the file src/utility/ask.sh from remote tegonal-scripts
#    # in the latest version and put into ./scripts/ instead of the default directory of this remote
#    # chop the repository path (i.e. src/utility), i.e. put ask.sh directly into ./scripts/
#    gt pull -r tegonal-scripts -p src/utility/ask.sh -d ./scripts/ --chop-path true
#
#    # pull the file src/utility/ask.sh from remote tegonal-scripts
#    # in the latest version and rename to asking.sh
#    gt pull -r tegonal-scripts -p src/utility/ask.sh --target-file-name asking.sh
#
#    # pull the file src/utility/checks.sh from remote tegonal-scripts
#    # in the latest version matching the specified tag-filter (i.e. one starting with v3)
#    gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/ --tag-filter "^v3.*"
#
#    # pull the file src/utility/checks.sh from remote tegonal-scripts in the latest version
#    # trust all gpg-keys stored in .gt/remotes/tegonal-scripts/public-keys
#    # if the remotes gpg sotre is not yet set up
#    gt pull -r tegonal-scripts --auto-trust true -p src/utlity/checks.sh
#
#    # pull the file src/utility/checks.sh from remote tegonal-scripts in the latest version
#    # Ignore if the gpg store of the remote is not set up and no suitable gpg key is defined in
#    # .gt/tegonal-scripts/public-keys. However, if the gpg store is setup or a suitable key is defined,
#    # then checks.sh will still be verified against it.
#    # (you might want to add --unsecure true to .gt/tegonal-scripts/pull.args if you never intend to
#    # set up gpg -- this way you don't have to repeat this option)
#    gt pull -r tegonal-scripts --unsecure true  -p src/utlity/checks.sh
#
#    # pull the file src/utility/checks.sh from remote tegonal-scripts in the latest version
#    # without verifying its signature (if defined) against the remotes gpg store
#    # you should not use this option unless you want to pull a file from a remote which signs files
#    # but has not signed the file you intend to pull.
#    gt pull -r tegonal-scripts --unsecure-no-verification true -p src/utlity/checks.sh
#
#    # pull the file src/utility/checks.sh from remote tegonal-scripts (in the custom working directory .github/.gt)
#    # in the latest version
#    gt pull -w .github/.gt -r tegonal-scripts -p src/utlity/checks.sh
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v1.1.0-SNAPSHOT'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_gt/pulled-utils.sh"
sourceOnce "$dir_of_gt/utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gt_pull_cleanupGpgDir() {
	local -r gpgDir=$1
	if [[ -d $gpgDir ]]; then
		deleteDirChmod777 "$gpgDir" &>/dev/null
	fi
}

function gt_pull_cleanupRepo() {
	# note, we want to cleanup also for normal exits, so no need to check for $?
	local -r repository=$1
	if [[ -d $repository ]]; then
		find "$repository" -maxdepth 1 -type d -not -path "$repository" -not -name ".git" -exec rm -r {} \;
	fi
}

function gt_pull_noop() {
	true
}

function gt_pull() {
	local startTime endTime elapsed
	startTime=$(date +%s.%3N)

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local pulledTsvLatestVersionPragma pulledTsvHeader signingKeyAsc targetFileNamePatternLong
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"
	local -r UNSECURE_NO_VERIFY_PATTERN='--unsecure-no-verification'

	local remote tag path pullDir chopPath targetFileName tagFilter autoTrust unsecure forceNoVerification workingDir
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		remote "$remoteParamPattern" 'name of the remote repository'
		tag "$tagParamPattern" 'git tag used to pull the file/directory'
		path "$pathParamPattern" 'path in remote repository which shall be pulled (file or directory)'
		pullDir "$pullDirParamPattern" "(optional) directory into which files are pulled -- default: pull directory of this remote (defined during \"remote add\" and stored in $defaultWorkingDir/<remote>/pull.args)"
		chopPath "$chopPathParamPattern" '(optional) if set to true, then files are put into the pull directory without the path specified. For files this means they are put directly into the pull directory'
		targetFileName "$targetFileNamePattern" '(optional) if you want to use a different file name then the one specified in the remote -- default: name as specified in the remote'
		tagFilter "$tagFilterParamPattern" "$tagFilterParamDocu"
		autoTrust "$autoTrustParamPattern" "$autoTrustParamDocu"
		unsecure "$unsecureParamPattern" "(optional) if set to true, the remote does not need to have GPG key(s) defined in gpg database or at $defaultWorkingDir/<remote>/*.asc -- default: false"
		forceNoVerification "$UNSECURE_NO_VERIFY_PATTERN" "(optional) if set to true, implies $unsecureParamPatternLong true and does not verify even if gpg keys are in store or at $defaultWorkingDir/<remote>/*.asc -- default: false"
		workingDir "$workingDirParamPattern" "$workingDirParamDocu"
	)

	local -r examples=$(
		# shellcheck disable=SC2312
		cat <<-EOM
			# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
			# in version v0.1.0 (i.e. tag v0.1.0 is used)
			# into the default directory of this remote
			gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

			# pull the directory src/utility/ from remote tegonal-scripts
			# in version v0.1.0 (i.e. tag v0.1.0 is used)
			gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/

			# pull the file .github/CODE_OF_CONDUCT.md and put it into the pull directory .github
			# without repeating the path (option --chop-path), i.e is pulled directly into .github/CODE_OF_CONDUCT.md
			# and not into .github/.github/CODE_OF_CONDUCT.md
			gt pull -r tegonal-scripts -t v0.1.0 -d .github --chop-path true -p .github/CODE_OF_CONDUCT.md

			# pull the file src/utility/checks.sh in the latest version matching the specified tag-filter
			# (i.e. a version starting with v3)
			gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/ --tag-filter "^v3.*"
		EOM
	)

	# parsing once so that we get workingDir and remote
	# redirecting output to /dev/null because we don't want to see 'ignored argument warnings' twice
	# || true because --help returns 99 and we don't want to exit at this point (because we redirect output)
	parseArguments params "$examples" "$GT_VERSION" "$@" >/dev/null || true
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi

	local -a args=()
	if [[ -v remote && -n $remote ]]; then
		# cannot be readonly as we override it in paths.source.sh as well, should be the same though
		local pullArgsFile="$workingDir/remotes/$remote/pull.args"
		if [[ -f $pullArgsFile ]]; then
			while read -r line; do
				eval 'args+=('"$line"');'
			done <"$pullArgsFile" || die "could not read %s, you might not execute what you want without it, aborting" "$pullArgsFile"
		fi
	fi
	args+=("$@")

	parseArguments params "$examples" "$GT_VERSION" "${args[@]}" || return $?

	if ! [[ -v chopPath ]]; then chopPath=false; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v forceNoVerification ]]; then forceNoVerification=false; fi
	if ! [[ -v unsecure ]]; then unsecure="$forceNoVerification"; fi
	local fakeTag="NOT_A_REAL_TAG_JUST_TEMPORARY"
	if ! [[ -v tag ]]; then tag="$fakeTag"; fi
	if ! [[ -v tagFilter ]]; then tagFilter=".*"; fi
	if ! [[ -v targetFileName ]]; then targetFileName=""; fi

	# before we report about missing arguments we check if the working directory exists and
	# if it is inside of the call location
	exitIfWorkingDirDoesNotExist "$workingDir"
	exitIfPathNamedIsOutsideOf "$workingDir" "working directory" "$currentDir"

	# if remote does not exist then pull.args does not and most likely pullDir is thus not defined, in this case we want
	# to show the error about the non existing remote before other missing arguments
	if ! [[ -v pullDir && -v workingDir && -n $workingDir ]] && [[ -v remote && -n $remote ]]; then
		exitIfRemoteDirDoesNotExist "$workingDir" "$remote"
	fi
	exitIfNotAllArgumentsSet params "$examples" "$GT_VERSION"

	exitIfRemoteDirDoesNotExist "$workingDir" "$remote"

	if [[ "$path" =~ ^/.* ]]; then
		die "Leading / not allowed for path, given: \033[0;36m%s\033[0m" "$path"
	fi

	if [[ "$targetFileName" =~ / ]]; then
		die "/ not allowed in the targetFileName, given %s" "$targetFileName"
	fi

	local workingDirAbsolute pullDirAbsolute
	workingDirAbsolute=$(readlink -m "$workingDir") || die "could not deduce workingDirAbsolute from %s" "$workingDir"
	pullDirAbsolute=$(readlink -m "$pullDir")
	local -r workingDirAbsolute pullDirAbsolute
	checkPathNamedIsInsideOf "$pullDirAbsolute" "pull directory" "$currentDir" || return $?

	local publicKeysDir repo gpgDir pulledTsv pullHookFile
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	if ! [[ -d $pullDirAbsolute ]]; then
		mkdir -p "$pullDirAbsolute" || die "failed to create the pull directory %s" "$pullDirAbsolute"
	fi

	if ! [[ -f $pulledTsv ]]; then
		echo "$pulledTsvLatestVersionPragma"$'\n'"$pulledTsvHeader" >"$pulledTsv" || die "failed to initialise the pulled.tsv file at \033[0;36m%s\033[0m" "$pulledTsv"
	else
		exitIfHeaderOfPulledTsvIsWrong "$pulledTsv"
	fi

	exitIfRepoBrokenAndReInitIfAbsent "$workingDirAbsolute" "$remote"

	local tagToPull="$tag"
	# tag was actually omitted, so we use the latest remote tag instead
	if [[ $tag == "$fakeTag" ]]; then
		tagToPull=$(latestRemoteTagIncludingChecks "$workingDirAbsolute" "$remote" "$tagFilter") || die "could not determine latest tag of remote \033[0;36m%s\033[0m, see above" "$remote"
	fi
	local -r tagToPull

	local doVerification
	if [[ $forceNoVerification == true ]]; then
		doVerification=false
	else
		doVerification=true
		if ! [[ -d $gpgDir ]]; then
			if [[ -f $gpgDir ]]; then
				die "looks like the remote \033[0;36m%s\033[0m is broken there is a file at the gpg dir's location: %s" "$remote" "$gpgDir"
			fi

			logInfo "gpg directory does not exist at %s\nWe are going to import %s from %s" "$gpgDir" "$signingKeyAsc" "$publicKeysDir"

			if ! [[ -f "$publicKeysDir/$signingKeyAsc" ]]; then
				if [[ $unsecure == true ]]; then
					logWarning "\033[0;36m%s\033[0m not found, won't be able to verify files (which is OK because '%s true' was specified)" "$signingKeyAsc" "$unsecureParamPatternLong"
					doVerification=false
					# we initialiseGpgDir so that we don't try it next time
					initialiseGpgDir "$gpgDir"
				else
					die "\033[0;36m%s\033[0m not defined in %s" "$signingKeyAsc" "$publicKeysDir"
				fi
			else
				# we want to expand $gpgDir here and not when signal happens (as $gpgDir might be out of scope), hence we ignore
				# shellcheck disable=SC2064
				# we use this trap to delete the gpgDir in case something goes wrong during the import, i.e. to avoid that that
				# we keep a gpg store with a non-trusted signing-key (which would then be used during gt pull and the like)
				trap "gt_pull_cleanupGpgDir '$gpgDir'" EXIT

				initialiseGpgDir "$gpgDir"

				local -i numberOfImportedKeys=0
				function gt_pull_importKeyCallback() {
					((++numberOfImportedKeys))
				}
				validateSigningKeyAndImport "$remote" "$publicKeysDir" "$gpgDir" "$publicKeysDir" gt_pull_importKeyCallback "$autoTrust"

				if ((numberOfImportedKeys == 0)); then
					if [[ $unsecure == true ]]; then
						logWarning "\033[0;36m%s\033[0m declined, won't be able to verify files (which is OK because '%s true' was specified)" "$signingKeyAsc" "$unsecureParamPatternLong"
						doVerification=false
					else
						exitBecauseSigningKeyNotImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecureParamPatternLong" "$signingKeyAsc"
					fi
				fi
			fi
		fi
		if [[ $unsecure == true && $doVerification == true ]]; then
			local trustDb="$gpgDir/trustdb.gpg"
			if [[ -f $trustDb ]]; then
				logInfo "gpg seems to be initialised (found %s), going to perform verification even though '%s true' was specified" "$unsecureParamPatternLong" "$trustDb"
			else
				doVerification=false
			fi
		fi
	fi

	# we want to expand $repo here and not when signal happens (as $repo might be out of scope)
	# shellcheck disable=SC2064
	# note, this replaces the previous EXIT trap gt_pull_cleanupGpgDir which is intentional, we want to keep the gpg dir
	# now that it was established
	trap "gt_pull_cleanupRepo '$repo'" EXIT

	askToDeleteAndReInitialiseGitDirIfRemoteIsBroken "$workingDirAbsolute" "$remote"

	local tags
	tags=$(git -C "$repo" tag) || die "The following command failed (see above): git tag"
	if grep "$tagToPull" <<<"$tags" >/dev/null; then
		logInfo "tag \033[0;36m%s\033[0m already exists locally, skipping fetching from remote \033[0;36m%s\033[0m" "$tagToPull" "$remote"
	else
		local remoteTags
		remoteTags=$(cd "$repo" && remoteTagsSorted "$remote") || (logInfo >&2 "check your internet connection" && return 1) || return $?
		grep "$tagToPull" <<<"$remoteTags" >/dev/null || returnDying "remote \033[0;36m%s\033[0m does not have the tag \033[0;36m%s\033[0m\nFollowing the available tags:\n%s" "$remote" "$tagToPull" "$remoteTags" || return $?
		git -C "$repo" fetch --depth 1 "$remote" "refs/tags/$tagToPull:refs/tags/$tagToPull" || returnDying "was not able to fetch tag %s from remote %s" "$tagToPull" "$remote" || return $?
	fi

	git -C "$repo" checkout "tags/$tagToPull" -- "$path" || returnDying "was not able to checkout tags/%s and path %s" "$tagToPull" "$path" || return $?

	if [[ -d "$repo/$path" ]] && [[ $targetFileName != "" ]]; then
		returnDying "you cannot specify %s when you pull a directory -- what you can do though:\n1. pull the directory\n2. rename the file(s) manually\n3. adjust the entries in %s\n\nNext time you gt re-pull or gt update the rename will be taken into account" "$targetFileNamePatternLong" "$pulledTsv" || return $?
	fi

	function gt_pull_mentionUnsecure() {
		if [[ $unsecure != true ]]; then
			printf " -- you can disable this check via: %s true\n" "$unsecureParamPatternLong"
		else
			printf " -- you can disable this check via: %s true\n" "$UNSECURE_NO_VERIFY_PATTERN"
		fi
	}

	local -r sigExtension="sig"

	function gt_pull_pullSignatureOfSingleFetchedFile() {
		# is path a file then fetch also the corresponding signature
		if [[ $doVerification == true && -f "$repo/$path" ]]; then
			if ! git -C "$repo" checkout "tags/$tagToPull" -- "$path.$sigExtension" && [[ $unsecure == false ]]; then
				logErrorWithoutNewline "no signature file found for \033[0;36m%s\033[0m, aborting pull from remote %s" "$path" "$remote"
				gt_pull_mentionUnsecure >&2
				return 1
			fi
		fi
	}
	gt_pull_pullSignatureOfSingleFetchedFile

	local pullHookBefore="gt_pull_noop"
	local pullHookAfter="gt_pull_noop"
	if [[ -f $pullHookFile ]]; then
		# shellcheck disable=SC2310		# we are aware of that || will disable set -e for sourceOnce
		sourceOnce "$pullHookFile" || traceAndDie "could not source %s" "$pullHookFile"
		pullHookBefore="gt_pullHook_${remote//-/_}_before"
		pullHookAfter="gt_pullHook_${remote//-/_}_after"
	fi

	local -i numberOfPulledFiles=0

	function gt_pull_moveFile() {
		local repoFile=$1

		local targetFile
		if [[ $chopPath == true ]]; then
			if [[ -d "$repo/$path" ]]; then
				local offset
				offset=$(if [[ $path == */ ]]; then echo 1; else echo 2; fi)
				targetFile="$(cut -c "$((${#path} + offset))"- <<<"$repoFile")" || returnDying "could not calculate the target file for \033[0;36m%s\033[0m" "$repoFile" || return $?
			else
				targetFile="$(basename "$repoFile")" || returnDying "could not calculate the target file for \033[0;36m%s\033[0m" "$repoFile" || return $?
			fi
		else
			targetFile="$repoFile"
		fi
		if [[ $targetFileName != "" ]]; then
			local targetPath
			targetPath=$(dirname "$targetFile")
			targetFile="${targetPath#./}/$targetFileName"
		fi
		local -r targetFile

		local -r absoluteTarget="$pullDirAbsolute/$targetFile"
		local parentDir
		parentDir=$(dirname "$absoluteTarget")
		# parent dir needs to be created before relativeTarget is determined because realpath expects an existing parent dir
		mkdir -p "$parentDir" || die "was not able to create the parent dir for %s" "$absoluteTarget"

		local source="$repo/$repoFile"

		local relativeTarget sha entry currentEntry
		relativeTarget=$(realpath --relative-to="$workingDirAbsolute" "$absoluteTarget") || returnDying "could not determine relativeTarget for \033[0;36m%s\033[0m" "$absoluteTarget" || return $?
		sha=$(sha512sum "$source" | cut -d " " -f 1) || returnDying "could not calculate sha12 for \033[0;36m%s\033[0m" "$source" || return $?
		entry=$(pulledTsvEntry "$tagToPull" "$repoFile" "$relativeTarget" "$tagFilter" "$sha") || returnDying "could not create pulled.tsv entry for tag %s and repoFile \033[0;36m%s\033[0m" "$tagToPull" "$repoFile" || return $?
		# perfectly fine if there is no entry, we return an empty string in this case for which we check further below
		currentEntry=$(grepPulledEntryByFile "$pulledTsv" "$repoFile" || echo "")
		local -r relativeTarget sha entry currentEntry

		local entryTag entrySha entryRelativePath
		setEntryVariables "$currentEntry"
		local -r entryTag entrySha entryRelativePath

		if [[ $currentEntry == "" ]]; then
			echo "$entry" >>"$pulledTsv" || die "was not able to append the entry for file %s to \033[0;36m%s\033[0m" "$repoFile" "$pulledTsv"
		elif [[ $entryTag != "$tagToPull" ]]; then
			logInfo "the file was pulled before in version %s, going to override with version %s \033[0;36m%s\033[0m" "$entryTag" "$tagToPull" "$repoFile"
			# we could warn about a version which was older
			replacePulledEntry "$pulledTsv" "$repoFile" "$entry"
		else
			if [[ $entrySha != "$sha" ]]; then
				logWarning "looks like the sha512 of \033[0;36m%s\033[0m changed in tag %s" "$repoFile" "$tagToPull"
				gitDiffChars "$entrySha" "$sha"
				printf "Won't pull the file, remove the entry from %s and \`gt pull\` if you want to pull it nonetheless\n" "$pulledTsv"
				rm "$source"
				return
			elif ! grep -x "$entry" "$pulledTsv" >/dev/null; then
				local currentLocation newLocation
				currentLocation=$(realpath --relative-to="$currentDir" "$workingDirAbsolute/$entryRelativePath" || echo "$workingDirAbsolute/$entryRelativePath")
				newLocation=$(realpath --relative-to="$currentDir" "$pullDir/$targetFile" || echo "$pullDir/$targetFile")
				local -r currentLocation newLocation
				logWarning "the file was previously pulled to a different location"
				echo "current location: $currentLocation"
				echo "    new location: $newLocation"
				printf "Won't pull the file again, you have several alternatives:\n- remove the entry from %s and pull it again\n- move the file manually and adjust the relativeTarget of the entry (and pull again)\n" "$pulledTsv"
				rm "$source"
				return
			elif [[ -f $absoluteTarget ]]; then
				logInfo "the file was pulled before to the same location, going to override \033[0;36m%s\033[0m" "$absoluteTarget"
			fi
		fi

		"$pullHookBefore" "$tagToPull" "$source" "$absoluteTarget" || returnDying "pull hook before failed for \033[0;36m%s\033[0m, will not move the file to its target %s" "$repoFile" "$absoluteTarget" || return $?
		mv "$source" "$absoluteTarget" || returnDying "was not able to move the file \033[0;36m%s\033[0m to %s" "$source" "$absoluteTarget" || return $?
		"$pullHookAfter" "$tagToPull" "$source" "$absoluteTarget" || returnDying "pull hook after failed for \033[0;36m%s\033[0m but the file was already moved, please do a manual cleanup" "$repoFile" "$absoluteTarget" || return $?

		((++numberOfPulledFiles))
	}

	local absoluteFile
	while read -r -d $'\0' absoluteFile; do
		# in theory this check should not be necessary as we already check that the pullDir is not outside
		# but better be sure as we don't want that `gt re-pull` can be a security risk (leaving pull-hooks aside)
		checkPathNamedIsInsideOf "$absoluteFile" "target path" "$currentDir" || return $?

		local repoFile
		repoFile=$(realpath --relative-to="$repo" "$absoluteFile")
		local -r sigFile="$absoluteFile.$sigExtension"
		if [[ $doVerification == true && -f $sigFile ]]; then
			printf "verifying \033[0;36m%s\033[0m from remote %s\n" "$repoFile" "$remote"
			if [[ -d "$pullDirAbsolute/$repoFile" ]]; then
				die "there exists a directory with the same name at %s" "$pullDirAbsolute/$repoFile"
			fi
			if gpg --homedir "$gpgDir" --verify "$sigFile" "$absoluteFile"; then
				local keyData keyId
				keyData=$(getSigningGpgKeyData "$sigFile" "$gpgDir") || die "could not get the key data of %s" "$sigFile"
				keyId=$(extractGpgKeyIdFromKeyData "$keyData")
				if isGpgKeyInKeyDataRevoked "$keyData"; then
					returnDying "the key %s which signed the file \033[0;36m%s\033[0m form remote %s was revoked" "$keyId" "$repoFile" "$remote" || return $?
				fi
			else
				returnDying "gpg verification failed for file \033[0;36m%s\033[0m from remote %s" "$repoFile" "$remote" || return $?
			fi
			# or true as we will try to cleanup the repo on exit
			rm "$sigFile" || true

			# we are aware of that || will disable set -e for gt_pull_moveFile, we need it as gt_pull is used in gt_update
			# and gt_re-pull in an if, i.e. set -e is disabled anyway, hence we return here to make sure we actually exit
			# the function
			# shellcheck disable=SC2310
			gt_pull_moveFile "$repoFile" || return $?

		elif [[ $doVerification == true ]]; then
			logWarningWithoutNewline "there was no corresponding *.%s file for %s in remote %s, skipping it" "$sigExtension" "$repoFile" "$remote"
			gt_pull_mentionUnsecure
			# or true as we will try to cleanup the repo on exit
			rm "$absoluteFile" || true
		else
			# we are aware of that || will disable set -e for gt_pull_moveFile, we need it as gt_pull is used in gt_update
			# and gt_re-pull in an if, i.e. set -e is disabled anyway, hence we return here to make sure we actually exit
			# the function
			# shellcheck disable=SC2310
			gt_pull_moveFile "$repoFile" || return $?
		fi
	done < <(find "$repo/$path" -type f -not -name "*.$sigExtension" -print0 ||
		# `while read` will fail because there is no \0
		true)

	endTime=$(date +%s.%3N)
	elapsed=$(bc <<<"scale=3; $endTime - $startTime")
	if ((numberOfPulledFiles > 1)); then
		logSuccess "%s files pulled from %s %s in %s seconds" "$numberOfPulledFiles" "$remote" "$path" "$elapsed"
	elif ((numberOfPulledFiles == 1)); then
		logSuccess "file %s pulled from %s in %s seconds" "$path" "$remote" "$elapsed"
	else
		returnDying "0 files could be pulled from %s, most likely verification failed, see above." "$remote"
	fi
}

${__SOURCED__:+return}
gt_pull "$@"
