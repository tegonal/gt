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

function gget-pull() {
	local scriptDir
	scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	local -r scriptDir
	local currentDir
	currentDir=$(pwd)
	local -r currentDir

	source "$scriptDir/shared-patterns.source.sh"
	source "$scriptDir/gpg-utils.sh"
	source "$scriptDir/pulled-utils.sh"
	source "$scriptDir/utils.sh"
	source "$scriptDir/../lib/tegonal-scripts/src/utility/parse-args.sh" || exit 200

	local -r UNSECURE_NO_VERIFY_PATTERN='--unsecure-no-verification'

	local remote tag path pullDir unsecure forceNoVerification workingDir
	# shellcheck disable=SC2034
	local -ar params=(
		remote "$remotePattern" 'name of the remote repository'
		tag '-t|--tag' 'git tag used to pull the file/directory'
		path '-p|--path' 'path in remote repository which shall be pulled (file or directory)'
		pullDir "$pullDirPattern" "(optional) directory into which files are pulled -- default: pull directory of this remote (defined during \"remote add\" and stored in $defaultWorkingDir/<remote>/pull.args)"
		workingDir "$workingDirPattern" "(optional) path which gget shall use as working directory -- default: $defaultWorkingDir"
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
	parseArguments params "$examples" "$@" >/dev/null || true
	if ! [ -v workingDir ]; then workingDir="$defaultWorkingDir"; fi

	local -a args=()
	if [ -v remote ] && [ -n "$remote" ]; then
		local -r pullArgsFile="$workingDir/remotes/$remote/pull.args"
		if [ -f "$pullArgsFile" ]; then
			defaultArguments=$(cat "$pullArgsFile")
			eval 'for arg in '"$defaultArguments"'; do
					args+=("$arg");
			done'
		fi
	fi
	args+=("$@")
	parseArguments params "$examples" "${args[@]}"

	if ! [ -v autoTrust ]; then autoTrust=false; fi
	if ! [ -v forceNoVerification ]; then forceNoVerification=false; fi
	if ! [ -v unsecure ]; then unsecure="$forceNoVerification"; fi
	checkAllArgumentsSet params "$examples"

	checkWorkingDirExists "$workingDir"

	# make directory paths absolute
	local -r workingDir=$(readlink -m "$workingDir")
	local -r pullDirAbsolute=$(readlink -m "$pullDir")

	local remoteDir publicKeysDir repo gpgDir pulledFile
	source "$scriptDir/paths.source.sh"

	local doVerification
	if [ "$forceNoVerification" == true ]; then
		doVerification=false
	else
		doVerification=true
		if ! [ -d "$gpgDir" ]; then
			if [ -f "$gpgDir" ]; then
				printf >&2 "\033[1;31mERROR\033[0m: looks like the remote \033[0;36m%s\033[0m is broken there is a file at the gpg dir's location: %s\n" "$remote" "$gpgDir"
				exit 1
			fi

			printf "\033[0;36mINFO\033[0m: gpg directory does not exist at %s\nWe are going to import all public keys which are stored in %s\n" "$gpgDir" "$publicKeysDir"

			# shellcheck disable=SC2310
			if noAscInDir "$publicKeysDir"; then
				if [ "$unsecure" == true ]; then
					printf "\033[1;33mWARNING\033[0m: no GPG key found, won't be able to verify files (which is OK because %s true was specified)\n" "$unsecurePattern"
					doVerification=false
				else
					printf >&2 "\033[1;31mERROR\033[0m: no public keys for remote \033[0;36m%s\033[0m defined in %s\n" "$remote" "$publicKeysDir"
					exit 1
				fi
			else
				mkdir "$gpgDir"
				chmod 700 "$gpgDir"
				local -r confirm="--confirm=$(set -e && invertBool "$autoTrust")"

				local -i numberOfImportedKeys=0
				function importKeys() {
					findAscInDir "$publicKeysDir" -print0 >&3
					while read -u 4 -r -d $'\0' file; do
						if importKey "$gpgDir" "$file" "$confirm"; then
							((numberOfImportedKeys += 1))
						fi
					done
				}
				withOutput3Input4 importKeys
				if ((numberOfImportedKeys == 0)); then
					if [ "$unsecure" == true ]; then
						printf "\033[1;33mWARNING\033[0m: all GPG keys declined, won't be able to verify files (which is OK because %s true was specified)\n" "$unsecurePattern"
						doVerification=false
					else
						errorNoGpgKeysImported "$remote" "$publicKeysDir" "$gpgDir" "$unsecurePattern"
					fi
				fi
			fi
		fi
		if [ "$unsecure" == true ] && [ "$doVerification" == true ]; then
			printf "\033[0;36mINFO\033[0m: gpg key found going to perform verification even though %s true was specified\n" "$unsecurePattern"
		fi
	fi

	if ! [ -d "$pullDirAbsolute" ]; then
		mkdir -p "$pullDirAbsolute" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create the pull directory %s\n" "$pullDirAbsolute" && exit 1)
	fi

	if [ -f "$repo" ]; then
		printf >&2 "\033[1;31mERROR\033[0m: looks like the remote \033[0;36m%s\033[0m is broken there is a file at the repo's location: %s\n" "$remote" "$remoteDir"
		exit 1
	elif ! [ -d "$repo" ]; then
		printf "\033[0;36mINFO\033[0m: repo directory does not exist for remote \033[0;36m%s\033[0m. We are going to re-initialise it based on the stored gitconfig\n" "$remote"
		mkdir -p "$repo"
		cd "$repo"
		git init
		cp "$remoteDir/gitconfig" "$repo/.git/config"
	fi

	cd "$repo"
	git ls-remote -t "$remote" | grep "$tag" >/dev/null || (printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m does not have arg tag \033[0;36m%s\033[0m\nFollowing the available tags:\n" "$remote" "$tag" && git ls-remote -t "$remote" && exit 1)

	# show commands as output
	set -x

	git fetch --depth 1 "$remote" "refs/tags/$tag:refs/tags/$tag"
	git checkout "tags/$tag" -- "$path"

	# don't show commands in output anymore
	{ set +x; } 2>/dev/null

	function mentionUnsecure() {
		if ! [ "$unsecure" == true ]; then
			printf " -- you can disable this check via %s true\n" "$unsecurePattern"
		else
			printf " -- you can disable this check via %s true\n" "$UNSECURE_NO_VERIFY_PATTERN"
		fi
	}

	local -r SIG_EXTENSION="sig"

	function getSignatureOfSingleFetchedFile() {
		if [ "$doVerification" == true ] && [ -f "$repo/$path" ]; then
			set -x
			# is arg file, fetch also the corresponding signature
			if ! git checkout "tags/$tag" -- "$path.$SIG_EXTENSION"; then
				# don't show commands in output anymore
				{ set +x; } 2>/dev/null

				printf >&2 "\033[1;31mERROR\033[0m: no signature file found, aborting"
				mentionUnsecure >&2
				exit 1
			fi

			# don't show commands in output anymore
			{ set +x; } 2>/dev/null
		fi
	}
	getSignatureOfSingleFetchedFile

	function cleanupRepo() {
		local -r repo=$1
		# cleanup the repo in case we exit unexpected
		find "$repo" -maxdepth 1 -type d -not -path "$repo" -not -name ".git" -exec rm -r {} \;
	}
	# local variable repo is not available for trap thus we expand it here via eval
	eval "trap 'cleanupRepo \"$repo\"' EXIT"

	if ! [ -f "$pulledFile" ]; then
		touch "$pulledFile" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create file pulled at %s\n" "$pulledFile" && exit 1)
	fi

	local -i numberOfPulledFiles=0

	function moveFile() {
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

		if [ "$currentEntry" == "" ]; then
			echo "$entry" >>"$pulledFile"
		elif ! [ "$entryTag" == "$tag" ]; then
			printf "\033[0;36mINFO\033[0m: the file was pulled before in version %s, going to override with version %s \033[0;36m%s\033[0m\n" "$entryTag" "$tag" "$pullDir/$file"
			# we could warn about a version which was older
			replacePulledEntry "$pulledFile" "$file" "$entry"
		else
			if ! [ "$entrySha" == "$sha" ]; then
				printf "\033[1;33mWARNING\033[0m: looks like the sha512 of \033[0;36m%s\033[0m changed in tag %s\n" "$file" "$tag"
				git --no-pager diff "$(echo "$entrySha" | git hash-object -w --stdin)" "$(echo "$sha" | git hash-object -w --stdin)" --word-diff=color --word-diff-regex . | grep -A 1 @@ | tail -n +2
				printf "Won't pull the file, remove the entry from %s if you want to pull it nonetheless\n" "$pulledFile"
				rm "$repo/$file"
				return
			elif ! grep "$entry" "$pulledFile" >/dev/null; then
				local currentLocation
				currentLocation=$(echo "$currentEntry" | perl -0777 -pe 's/[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)/$1/')
				printf "\033[1;33mWARNING\033[0m: the file was previously pulled to \033[0;36m%s\033[0m (new location would have been %s)\n" "$(realpath --relative-to="$currentDir" "$workingDir/$currentLocation")" "$pullDir/$file"
				printf "Won't pull the file again, remove the entry from %s if you want to pull it nonetheless\n" "$pulledFile"
				rm "$repo/$file"
				return
			elif [ -f "$absoluteTarget" ]; then
				printf "\033[0;36mINFO\033[0m: the file was pulled before to the same location, going to override \033[0;36m%s\033[0m\n" "$pullDir/$file"
			fi
		fi
		mv "$repo/$file" "$absoluteTarget"

		((numberOfPulledFiles += 1))
	}

	while read -r -d $'\0' file; do
		if [ "$doVerification" == true ] && [ -f "$file.$SIG_EXTENSION" ]; then
			printf "verifying \033[0;36m%s\033[0m\n" "$file"
			if [ -d "$pullDirAbsolute/$file" ]; then
				printf >&2 "\033[1;31mERROR\033[0m: there exists a directory with the same name at %s\n" "$pullDirAbsolute/$file"
				exit 1
			fi
			gpg --homedir="$gpgDir" --verify "$file.$SIG_EXTENSION" "$file"
			rm "$file.$SIG_EXTENSION"
			moveFile "$file"
		elif [ "$doVerification" == true ]; then
			printf "\033[1;33mWARNING\033[0m: there was no corresponding *.%s file for %s, skipping it" "$SIG_EXTENSION" "$file"
			mentionUnsecure
			rm "$file"
		else
			moveFile "$file"
		fi
	done < <(find "$path" -type f -not -name "*.$SIG_EXTENSION" -print0)

	if ((numberOfPulledFiles > 0)); then
		printf "\033[1;32mSUCCESS\033[0m: %s files pulled from %s %s\n" "$numberOfPulledFiles" "$remote" "$path"
	else
		printf >&2 "\033[1;31mERROR\033[0m: 0 files could be pulled from %s, most likely verification failed, see above.\n" "$remote"
		exit 1
	fi

}

gget-pull "$@"
