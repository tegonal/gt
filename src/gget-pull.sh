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
#  'pull' command of gget: utility to pull files from a previously defined git remote repository
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
#    # in version v0.1.0 (i.e. tag v0.1.0 is used)
#    gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh
#
#    # pull the directory src/utility/ from remote tegonal-scripts
#    # in version v0.1.0 (i.e. tag v0.1.0 is used)
#    gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/
#
###################################
set -euo pipefail
export GGET_VERSION='v0.2.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	declare -r dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gget/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_gget/pulled-utils.sh"
sourceOnce "$dir_of_gget/utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget_pull_cleanupRepo() {
	# maybe we still show commands at this point due to unexpected exit, thus turn it of just in case
	{ set +x; } 2>/dev/null

	local -r repository=$1
	find "$repository" -maxdepth 1 -type d -not -path "$repo" -not -name ".git" -exec rm -r {} \;
}

function gget_pull() {
	source "$dir_of_gget/shared-patterns.source.sh"
	local -r UNSECURE_NO_VERIFY_PATTERN='--unsecure-no-verification'

	local currentDir
	currentDir=$(pwd)
	local -r currentDir

	local remote tag path pullDirMaybeRelative chopPath workingDirMaybeRelative autoTrust unsecure forceNoVerification
	# shellcheck disable=SC2034
	local -ra params=(
		remote "$remotePattern" 'name of the remote repository'
		tag '-t|--tag' 'git tag used to pull the file/directory'
		path '-p|--path' 'path in remote repository which shall be pulled (file or directory)'
		pullDirMaybeRelative "$pullDirPattern" "(optional) directory into which files are pulled -- default: pull directory of this remote (defined during \"remote add\" and stored in $defaultWorkingDir/<remote>/pull.args)"
		chopPath "--chop-path" '(optional) if set to true, then files are put into the pull directory without the path specified. For files this means they are put directly into the pull directory'
		workingDirMaybeRelative "$workingDirPattern" "$workingDirParamDocu"
		autoTrust "$autoTrustPattern" "$autoTrustParamDocu"
		unsecure "$unsecurePattern" "(optional) if set to true, the remote does not need to have GPG key(s) defined in gpg databse or at $defaultWorkingDir/<remote>/*.asc -- default: false"
		forceNoVerification "$UNSECURE_NO_VERIFY_PATTERN" "(optional) if set to true, implies $unsecurePattern true and does not verify even if gpg keys are in store or at $defaultWorkingDir/<remote>/*.asc -- default: false"
	)

	local -r examples=$(
		cat <<-EOM
			# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
			# in version v0.1.0 (i.e. tag v0.1.0 is used)
			gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

			# pull the directory src/utility/ from remote tegonal-scripts
			# in version v0.1.0 (i.e. tag v0.1.0 is used)
			gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/

			# pull the file .github/CODE_OF_CONDUCT.md and put it into the pull directory .github
			# without repeating the path (option --chop-path), i.e is pulled directly into .github/CODE_OF_CONDUCT.md
			# and not into .github/.github/CODE_OF_CONDUCT.md
			gget pull -r tegonal-scripts -t v0.1.0 -d .github --chop-path true -p .github/CODE_OF_CONDUCT.md
		EOM
	)

	# parsing once so that we get workingDir and remote
	# redirecting output to /dev/null because we don't want to see 'ignored argument warnings' twice
	# || true because --help returns 99 and we don't want to exit at this point (because we redirect output)
	parseArguments params "$examples" "$GGET_VERSION" "$@" >/dev/null || true
	if ! [[ -v workingDirMaybeRelative ]]; then workingDirMaybeRelative="$defaultWorkingDir"; fi

	local -a args=()
	if [[ -v remote ]] && [[ -n $remote ]]; then
		local -r pullArgsFile="$workingDirMaybeRelative/remotes/$remote/pull.args"
		if [[ -f $pullArgsFile ]]; then
			defaultArguments=$(cat "$pullArgsFile")
			eval 'for arg in '"$defaultArguments"'; do
					args+=("$arg");
			done'
		fi
	fi
	args+=("$@")
	parseArguments params "$examples" "$GGET_VERSION" "${args[@]}"

	if ! [[ -v chopPath ]]; then chopPath=false; fi
	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v forceNoVerification ]]; then forceNoVerification=false; fi
	if ! [[ -v unsecure ]]; then unsecure="$forceNoVerification"; fi
	checkAllArgumentsSet params "$examples" "$GGET_VERSION"

	# make directory paths absolute
	local -r workingDir=$(readlink -m "$workingDirMaybeRelative")
	local -r pullDir=$(readlink -m "$pullDirMaybeRelative")

	checkWorkingDirExists "$workingDir"
	checkRemoteDirExists "$workingDir" "$remote"

	local remoteDir publicKeysDir repo gpgDir pulledTsv
	source "$dir_of_gget/paths.source.sh"

	if ! [[ -d $pullDir ]]; then
		mkdir -p "$pullDir" || returnDying "failed to create the pull directory %s" "$pullDir"
	fi

	if ! [[ -f $pulledTsv ]]; then
		pulledTsvHeader >"$pulledTsv" || returnDying "failed to initialise the pulled.tsv file at %s" "$pulledTsv"
	else
		checkHeaderOfPulledTsv "$pulledTsv"
	fi

	if [[ -f $repo ]]; then
		returnDying "looks like the remote \033[0;36m%s\033[0m is broken there is a file at the repo's location: %s" "$remote" "$remoteDir"
	elif ! [[ -d $repo ]]; then
		logInfo "repo directory does not exist for remote \033[0;36m%s\033[0m. We are going to re-initialise it based on the stored gitconfig" "$remote"
		mkdir -p "$repo"
		cd "$repo"
		git init
		cp "$remoteDir/gitconfig" "$repo/.git/config"
	fi

	local doVerification
	if [[ $forceNoVerification == true ]]; then
		doVerification=false
	else
		doVerification=true
		if ! [[ -d $gpgDir ]]; then
			if [[ -f $gpgDir ]]; then
				returnDying "looks like the remote \033[0;36m%s\033[0m is broken there is a file at the gpg dir's location: %s" "$remote" "$gpgDir"
			fi

			logInfo "gpg directory does not exist at %s\nWe are going to import all public keys which are stored in %s" "$gpgDir" "$publicKeysDir"

			if noAscInDir "$publicKeysDir"; then
				if [[ $unsecure == true ]]; then
					logWarning "no GPG key found, won't be able to verify files (which is OK because %s true was specified)" "$unsecurePattern"
					doVerification=false
				else
					returnDying "no public keys for remote \033[0;36m%s\033[0m defined in %s" "$remote" "$publicKeysDir"
				fi
			else
				mkdir "$gpgDir"
				chmod 700 "$gpgDir"
				local -r confirm="--confirm=$(set -e && invertBool "$autoTrust")"

				local -i numberOfImportedKeys=0
				function gget_pull_importGpgKeys() {
					findAscInDir "$publicKeysDir" -print0 >&3
					while read -u 4 -r -d $'\0' file; do
						if importGpgKey "$gpgDir" "$file" "$confirm"; then
							((++numberOfImportedKeys))
						fi
					done
				}
				withCustomOutputInput 3 4 gget_pull_importGpgKeys
				if ((numberOfImportedKeys == 0)); then
					if [[ $unsecure == true ]]; then
						logWarning "all GPG keys declined, won't be able to verify files (which is OK because %s true was specified)" "$unsecurePattern"
						doVerification=false
					else
						errorNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecurePattern"
					fi
				fi
			fi
		fi
		if [[ $unsecure == true && $doVerification == true ]]; then
			logInfo "gpg key found going to perform verification even though %s true was specified" "$unsecurePattern"
		fi
	fi

	# we want to expand $repo here and not when signal happens (as $repo might be out of scope)
	# shellcheck disable=SC2064
	trap "gget_pull_cleanupRepo '$repo'" EXIT SIGINT

	cd "$repo"
	local remoteTags
	remoteTags=$(git ls-remote -t "$remote" || (logInfo >&2 "check your internet connection" && return 1))
	echo "$remoteTags" | grep "$tag" >/dev/null || (returnDying "remote \033[0;36m%s\033[0m does not have the tag \033[0;36m%s\033[0m\nFollowing the available tags:\n%s" "$remote" "$tag" "$remoteTags")

	# show commands as output
	set -x

	git fetch --depth 1 "$remote" "refs/tags/$tag:refs/tags/$tag"
	git checkout "tags/$tag" -- "$path"

	# don't show commands in output anymore
	{ set +x; } 2>/dev/null

	function gget_pull_mentionUnsecure() {
		if ! [[ $unsecure == true ]]; then
			printf " -- you can disable this check via %s true\n" "$unsecurePattern"
		else
			printf " -- you can disable this check via %s true\n" "$UNSECURE_NO_VERIFY_PATTERN"
		fi
	}

	local -r sigExtension="sig"

	function gget_pull_pullSignatureOfSingleFetchedFile() {
		# is path a file then fetch also the corresponding signature
		if [[ $doVerification == true && -f "$repo/$path" ]]; then
			set -x
			if ! git checkout "tags/$tag" -- "$path.$sigExtension"; then
				# don't show commands in output anymore
				{ set +x; } 2>/dev/null

				logErrorWithoutNewline "no signature file found, aborting"
				gget_pull_mentionUnsecure >&2
				return 1
			fi

			# don't show commands in output anymore
			{ set +x; } 2>/dev/null
		fi
	}
	gget_pull_pullSignatureOfSingleFetchedFile

	local -i numberOfPulledFiles=0

	function gget_pull_moveFile() {
		local file=$1

		local targetFile
		if [[ $chopPath == true ]]; then
			if [[ -d "$repo/$path" ]]; then
				local -r offset=$(if [[ $path == */ ]]; then echo 1; else echo 2; fi)
				targetFile="$(echo "$file" | cut -c "$((${#path} + offset))"-)"
			else
				targetFile="$(basename "$file")"
			fi
		else
			targetFile="$file"
		fi
		local -r absoluteTarget="$pullDir/$targetFile"
		# parent dir needs to be created before relativeTarget is determined because realpath expects an existing parent dir
		mkdir -p "$(dirname "$absoluteTarget")"
		local relativeTarget
		relativeTarget=$(realpath --relative-to="$workingDir" "$absoluteTarget")
		local sha
		sha=$(sha512sum "$repo/$file" | cut -d " " -f 1)
		local -r entry=$(pulledTsvEntry "$tag" "$file" "$relativeTarget" "$sha")
		#shellcheck disable=SC2310,SC2311
		local -r currentEntry=$(grepPulledEntryByFile "$pulledTsv" "$file")
		local entryTag entrySha entryRelativePath
		setEntryVariables "$currentEntry"

		if [[ $currentEntry == "" ]]; then
			echo "$entry" >>"$pulledTsv"
		elif ! [[ $entryTag == "$tag" ]]; then
			logInfo "the file was pulled before in version %s, going to override with version %s \033[0;36m%s\033[0m" "$entryTag" "$tag" "$file"
			# we could warn about a version which was older
			replacePulledEntry "$pulledTsv" "$file" "$entry"
		else
			if ! [[ $entrySha == "$sha" ]]; then
				logWarning "looks like the sha512 of \033[0;36m%s\033[0m changed in tag %s" "$file" "$tag"
				gitDiffChars "$entrySha" "$sha"
				printf "Won't pull the file, remove the entry from %s if you want to pull it nonetheless\n" "$pulledTsv"
				rm "$repo/$file"
				return
			elif ! grep --line-regexp "$entry" "$pulledTsv" >/dev/null; then
				local -r currentLocation=$(realpath --relative-to="$currentDir" "$workingDir/$entryRelativePath" || echo "$workingDir/$entryRelativePath")
				local -r newLocation=$(realpath --relative-to="$currentDir" "$pullDirMaybeRelative/$targetFile" || echo "$pullDirMaybeRelative/$targetFile")
				logWarning "the file was previously pulled to a different location"
				echo "current location: $currentLocation"
				echo "    new location: $newLocation"
				printf "Won't pull the file again, remove the entry from %s if you want to pull it nonetheless\n" "$pulledTsv"
				rm "$repo/$file"
				return
			elif [[ -f $absoluteTarget ]]; then
				logInfo "the file was pulled before to the same location, going to override \033[0;36m%s\033[0m" "$pullDirMaybeRelative/$file"
			fi
		fi

		mv "$repo/$file" "$absoluteTarget"

		((++numberOfPulledFiles))
	}

	while read -r -d $'\0' file; do
		if [[ $doVerification == true && -f "$file.$sigExtension" ]]; then
			printf "verifying \033[0;36m%s\033[0m\n" "$file"
			if [[ -d "$pullDir/$file" ]]; then
				returnDying "there exists a directory with the same name at %s" "$pullDir/$file"
			fi
			gpg --homedir="$gpgDir" --verify "$file.$sigExtension" "$file"
			rm "$file.$sigExtension"
			gget_pull_moveFile "$file"
		elif [[ $doVerification == true ]]; then
			logWarningWithoutNewline "there was no corresponding *.%s file for %s, skipping it" "$sigExtension" "$file"
			gget_pull_mentionUnsecure
			rm "$file"
		else
			gget_pull_moveFile "$file"
		fi
	done < <(find "$path" -type f -not -name "*.$sigExtension" -print0)

	if ((numberOfPulledFiles > 1)); then
		logSuccess "%s files pulled from %s %s" "$numberOfPulledFiles" "$remote" "$path"
	elif ((numberOfPulledFiles = 1)); then
		logSuccess "file %s pulled from %s" "$path" "$remote"
	else
		returnDying "0 files could be pulled from %s, most likely verification failed, see above." "$remote"
	fi
	exit 0
}

${__SOURCED__:+return}
gget_pull "$@"
