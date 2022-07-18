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
set -eu
declare -x GGET_VERSION='v0.1.0-SNAPSHOT'

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
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function gget-pull-cleanupRepo() {
	local -r repository=$1
	find "$repository" -maxdepth 1 -type d -not -path "$repo" -not -name ".git" -exec rm -r {} \;
}

function gget-pull() {
	source "$dir_of_gget/shared-patterns.source.sh"
	local -r UNSECURE_NO_VERIFY_PATTERN='--unsecure-no-verification'

	local currentDir
	currentDir=$(pwd)
	local -r currentDir

	local remote tag path pullDir unsecure forceNoVerification workingDir
	# shellcheck disable=SC2034
	local -ra params=(
		remote "$remotePattern" 'name of the remote repository'
		tag '-t|--tag' 'git tag used to pull the file/directory'
		path '-p|--path' 'path in remote repository which shall be pulled (file or directory)'
		pullDir "$pullDirPattern" "(optional) directory into which files are pulled -- default: pull directory of this remote (defined during \"remote add\" and stored in $defaultWorkingDir/<remote>/pull.args)"
		workingDir "$workingDirPattern" "$workingDirParamDocu"
		autoTrust "$autoTrustPattern" "(optional) if set to true, all public-keys stored in $defaultWorkingDir/remotes/<remote>/public-keys/*.asc are imported without manual consent -- default: false"
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
		EOM
	)

	# parsing once so that we get workingDir and remote
	# redirecting output to /dev/null because we don't want to see 'ignored argument warnings' twice
	# || true because --help returns 99 and we don't want to exit at this point (because we redirect output)
	# shellcheck disable=SC2310
	parseArguments params "$examples" "$GGET_VERSION" "$@" >/dev/null || true
	if ! [[ -v workingDir ]]; then workingDir="$defaultWorkingDir"; fi

	local -a args=()
	if [[ -v remote ]] && [[ -n $remote ]]; then
		local -r pullArgsFile="$workingDir/remotes/$remote/pull.args"
		if [[ -f $pullArgsFile ]]; then
			defaultArguments=$(cat "$pullArgsFile")
			eval 'for arg in '"$defaultArguments"'; do
					args+=("$arg");
			done'
		fi
	fi
	args+=("$@")
	parseArguments params "$examples" "$GGET_VERSION" "${args[@]}"

	if ! [[ -v autoTrust ]]; then autoTrust=false; fi
	if ! [[ -v forceNoVerification ]]; then forceNoVerification=false; fi
	if ! [[ -v unsecure ]]; then unsecure="$forceNoVerification"; fi
	checkAllArgumentsSet params "$examples" "$GGET_VERSION"

	checkWorkingDirExists "$workingDir"

	# make directory paths absolute
	local -r workingDir=$(readlink -m "$workingDir")
	local -r pullDirAbsolute=$(readlink -m "$pullDir")

	local remoteDir publicKeysDir repo gpgDir pulledFile
	source "$dir_of_gget/paths.source.sh"

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

			# shellcheck disable=SC2310
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
				function gget-pull-importGpgKeys() {
					findAscInDir "$publicKeysDir" -print0 >&3
					while read -u 4 -r -d $'\0' file; do
						if importGpgKey "$gpgDir" "$file" "$confirm"; then
							((++numberOfImportedKeys))
						fi
					done
				}
				withOutput3Input4 gget-pull-importGpgKeys
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

	if ! [[ -d $pullDirAbsolute ]]; then
		mkdir -p "$pullDirAbsolute" || returnDying "failed to create the pull directory %s" "$pullDirAbsolute"
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

	cd "$repo"
	git ls-remote -t "$remote" | grep "$tag" >/dev/null || (printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m does not have the tag \033[0;36m%s\033[0m\nFollowing the available tags:\n" "$remote" "$tag" && git ls-remote -t "$remote" && exit 1)

	# show commands as output
	set -x

	git fetch --depth 1 "$remote" "refs/tags/$tag:refs/tags/$tag"
	git checkout "tags/$tag" -- "$path"

	# don't show commands in output anymore
	{ set +x; } 2>/dev/null

	function gget-pull-mentionUnsecure() {
		if ! [[ $unsecure == true ]]; then
			printf " -- you can disable this check via %s true\n" "$unsecurePattern"
		else
			printf " -- you can disable this check via %s true\n" "$UNSECURE_NO_VERIFY_PATTERN"
		fi
	}

	local -r SIG_EXTENSION="sig"

	function gget-pull-getSignatureOfSingleFetchedFile() {
		if [[ $doVerification == true && -f "$repo/$path" ]]; then
			set -x
			# is arg file, fetch also the corresponding signature
			if ! git checkout "tags/$tag" -- "$path.$SIG_EXTENSION"; then
				# don't show commands in output anymore
				{ set +x; } 2>/dev/null

				logErrorWithoutNewline "no signature file found, aborting"
				gget-pull-mentionUnsecure >&2
				return 1
			fi

			# don't show commands in output anymore
			{ set +x; } 2>/dev/null
		fi
	}
	gget-pull-getSignatureOfSingleFetchedFile

	trap 'gget-pull-cleanupRepo $repo' EXIT

	if ! [[ -f $pulledFile ]]; then
		touch "$pulledFile" || returnDying "failed to create file pulled at %s" "$pulledFile"
	fi

	local -i numberOfPulledFiles=0

	function gget-pull-moveFile() {
		local file=$1

		local -r absoluteTarget="$pullDirAbsolute/$file"
		# parent dir needs to be created before relativeTarget as realpath expects existing parent dirs
		mkdir -p "$(dirname "$absoluteTarget")"
		local relativeTarget
		relativeTarget=$(realpath --relative-to="$workingDir" "$pullDirAbsolute/$file")
		local sha
		sha=$(sha512sum "$repo/$file" | cut -d " " -f 1)
		local -r entry="$tag	$file	$sha	$relativeTarget"

		#shellcheck disable=SC2310,SC2311
		local -r currentEntry=$(grepPulledEntryByFile "$pulledFile" "$file" || true)
		local entryTag entrySha
		setEntryVariables "$currentEntry"

		if [[ $currentEntry == "" ]]; then
			echo "$entry" >>"$pulledFile"
		elif ! [[ $entryTag == "$tag" ]]; then
			logInfo "the file was pulled before in version %s, going to override with version %s \033[0;36m%s\033[0m" "$entryTag" "$tag" "$pullDir/$file"
			# we could warn about a version which was older
			replacePulledEntry "$pulledFile" "$file" "$entry"
		else
			if ! [[ $entrySha == "$sha" ]]; then
				logWarning "looks like the sha512 of \033[0;36m%s\033[0m changed in tag %s" "$file" "$tag"
				git --no-pager diff "$(echo "$entrySha" | git hash-object -w --stdin)" "$(echo "$sha" | git hash-object -w --stdin)" --word-diff=color --word-diff-regex . | grep -A 1 @@ | tail -n +2
				printf "Won't pull the file, remove the entry from %s if you want to pull it nonetheless\n" "$pulledFile"
				rm "$repo/$file"
				return
			elif ! grep "$entry" "$pulledFile" >/dev/null; then
				local currentLocation
				currentLocation=$(echo "$currentEntry" | perl -0777 -pe 's/[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)/$1/')
				logWarning "the file was previously pulled to \033[0;36m%s\033[0m (new location would have been %s)" "$(realpath --relative-to="$currentDir" "$workingDir/$currentLocation")" "$pullDir/$file"
				printf "Won't pull the file again, remove the entry from %s if you want to pull it nonetheless\n" "$pulledFile"
				rm "$repo/$file"
				return
			elif [[ -f $absoluteTarget ]]; then
				logInfo "the file was pulled before to the same location, going to override \033[0;36m%s\033[0m" "$pullDir/$file"
			fi
		fi
		mv "$repo/$file" "$absoluteTarget"

		((++numberOfPulledFiles))
	}

	while read -r -d $'\0' file; do
		if [[ $doVerification == true && -f "$file.$SIG_EXTENSION" ]]; then
			printf "verifying \033[0;36m%s\033[0m\n" "$file"
			if [[ -d "$pullDirAbsolute/$file" ]]; then
				returnDying "there exists a directory with the same name at %s" "$pullDirAbsolute/$file"
			fi
			gpg --homedir="$gpgDir" --verify "$file.$SIG_EXTENSION" "$file"
			rm "$file.$SIG_EXTENSION"
			gget-pull-moveFile "$file"
		elif [[ $doVerification == true ]]; then
			logWarningWithoutNewline "there was no corresponding *.%s file for %s, skipping it" "$SIG_EXTENSION" "$file"
			gget-pull-mentionUnsecure
			rm "$file"
		else
			gget-pull-moveFile "$file"
		fi
	done < <(find "$path" -type f -not -name "*.$SIG_EXTENSION" -print0)

	if ((numberOfPulledFiles > 1)); then
		logSuccess "%s files pulled from %s %s" "$numberOfPulledFiles" "$remote" "$path"
	elif ((numberOfPulledFiles = 1)); then
		logSuccess "file %s pulled from %s" "$path" "$remote"
	else
		returnDying "0 files could be pulled from %s, most likely verification failed, see above." "$remote"
	fi
	exit 0
}

gget-pull "$@"
