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

set -e

declare remote tag path pullDirectory unsecure forceNoVerification workingDirectory
# shellcheck disable=SC2034
declare params=(
	remote '-r|--remote' 'define the name of the remote repository to use'
	tag '-t|--tag' 'define which tag should be used to pull the file/directory'
	path '-p|--path' 'define which file or directory shall be fetched'
	pullDirectory '-d|--directory' '(optional) define into which directory files of this remote will be pulled -- default: pull directory of this remote (defined during "remote add" and stored in .gget/<remote>/pull.args)'
	workingDirectory '-w|--working-directory' '(optional) define arg path which gget shall use as working directory -- default: .gget'
	unsecure '--unsecure' '(optional) if set to true, the remote does not need to have GPG key(s) defined at .gget/<remote>/*.asc -- default: false'
	forceNoVerification '--unsecure-no-verification' '(optional) if set to true, implies --unsecure true and does not verify even if gpg keys were found at .gget/<remote>/*.asc -- default: false'
)

declare examples
examples=$(
	cat <<-EOM
		# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
		# in version v0.1.0 (i.e. tag v0.1.0 is used)
		gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

		# pull the directory src/utility/ from remote tegonal-scripts
		# in version v0.1.0 (i.e. tag v0.1.0 is used)
		gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/
	EOM
)

current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
source "$current_dir/gpg-utils.sh"
source "$current_dir/../lib/tegonal-scripts/src/utility/parse-args.sh" || exit 200

declare currentDir
currentDir=$(pwd)

# parsing once so that we get workingDirectory and remote
# redirecting output to /dev/null because we don't want to see 'ignored argument warnings' twice
# || true because --help returns 99 and we don't want to exit at this point (because we redirect output)
parseArguments params "$examples" "$@" >/dev/null || true
if ! [ -v workingDirectory ]; then workingDirectory="./.gget"; fi

declare args=()
if [ -n "$remote" ]; then
	declare pullArgsFile="$workingDirectory/$remote/pull.args"
	if [ -f "$pullArgsFile" ]; then
		defaultArguments=$(cat "$pullArgsFile")
		eval 'for arg in '"$defaultArguments"'; do
			args+=("$arg");
	done'
	fi
fi
args+=("$@")
parseArguments params "$examples" "${args[@]}"

if ! [ -v forceNoVerification ]; then forceNoVerification=false; fi
if ! [ -v unsecure ]; then unsecure="$forceNoVerification"; fi
checkAllArgumentsSet params "$examples"

if ! [ -d "$workingDirectory" ]; then
	printf >&2 "\033[1;31mERROR\033[0m: working directory \033[0;36m%s\033[0m does not exist\n" "$workingDirectory"
	echo >&2 "Check for typos and/or use $WORKING_DIR_PATTERN to specify another"
	exit 9
fi

# make directory paths absolute
workingDirectory=$(readlink -m "$workingDirectory")
declare pullDirectoryAbsolute
pullDirectoryAbsolute=$(readlink -m "$pullDirectory")

declare remoteDirectory="$workingDirectory/$remote"
declare repo="$remoteDirectory/repo"
declare publicKeys="$remoteDirectory/public-keys"
declare gpgDir="$publicKeys/gpg"

declare doVerification
if [ "$forceNoVerification" == true ]; then
	doVerification=false
else
	doVerification=true
	if ! [ -d "$gpgDir" ]; then
		printf "\033[0;36mINFO\033[0m: no gpg dir in %s\nWe are going to import all public keys which are stored in %s\n" "$gpgDir" "$publicKeys"
		function findAsc() {
			find "$publicKeys" -maxdepth 1 -type f -name "*.asc" "$@"
		}
		if (($(findAsc | wc -l) == 0)); then
			if [ "$unsecure" == true ]; then
				printf "\033[1;33mWARNING\033[0m: no GPG key found, won't be able to verify files (which is OK because --unsecure true was specified)\n"
				doVerification=false
			else
				printf >&2 "\033[1;31mERROR\033[0m: no public keys for remote \033[0;36m%s\033[0m defined in %s\n" "$remote" "$publicKeys"
				exit 1
			fi
		else
			mkdir "$gpgDir"
			chmod 700 "$gpgDir"
			findAsc -print0 |
				while read -r -d $'\0' file; do
					importKey "$gpgDir" "$file" --confirm=false
				done
		fi
	fi
	if [ "$unsecure" == true ] && [ "$doVerification" == true ]; then
		printf "\033[0;36mINFO\033[0m: gpg key found going to perform verification even though --unsecure true was specified\n"
	fi
fi

if ! [ -d "$pullDirectoryAbsolute" ]; then
	mkdir -p "$pullDirectoryAbsolute" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create the pull directory %s\n" "$pullDirectoryAbsolute" && exit 1)
fi

if [ -f "$repo" ]; then
	printf >&2 "\033[1;31mERROR\033[0m: looks like the remote \033[0;36m%s\033[0m is broken there is a file at the repo's location: %s\n" "$remote" "$remoteDirectory"
	exit 1
elif ! [ -d "$repo" ]; then
	printf "\033[0;36mINFO\033[0m: repo directory does not exist for remote \033[0;36m%s\033[0m. We are going to re-initialise it based on the stored gitconfig\n" "$remote"
	mkdir -p "$repo"
	cd "$repo"
	git init
	cp "$remoteDirectory/gitconfig" "$repo/.git/config"
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
		printf "Disable this check via --unsecure true\n"
	else
		printf "Disable this check via --unsecure-no-verification true\n"
	fi
}

declare sigExtension="sig"

function getSignatureOfSingleFetchedFile() {
	if [ "$doVerification" == true ] && [ -f "$repo/$path" ]; then
		set -x
		# is arg file, fetch also the corresponding signature
		if ! git checkout "tags/$tag" -- "$path.$sigExtension"; then
			# don't show commands in output anymore
			{ set +x; } 2>/dev/null

			printf >&2 "\033[1;31mERROR\033[0m: no signature file found, aborting. "
			mentionUnsecure >&2
			exit 1
		fi

		# don't show commands in output anymore
		{ set +x; } 2>/dev/null
	fi
}
getSignatureOfSingleFetchedFile

function cleanupRepo() {
	# cleanup the repo in case we exit unexpected
	find "$repo" -maxdepth 1 -type d -not -path "$repo" -not -name ".git" -exec rm -r {} \;
}

trap cleanupRepo EXIT

declare numberOfPulledFiles=0
declare pulledFiles="$remoteDirectory/pulled"
if ! [ -f "$pulledFiles" ]; then
	touch "$pulledFiles" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create pulled at %s\n" "$pulledFiles" && exit 1)
fi

function moveFile() {
	local file=$1

	declare relativeTarget
	relativeTarget=$(realpath --relative-to="$workingDirectory" "$pullDirectoryAbsolute/$file")
	declare absoluteTarget
	absoluteTarget="$pullDirectoryAbsolute/$file"
	mkdir -p "$(dirname "$absoluteTarget")"
	declare sha
	sha=$(sha512sum "$repo/$file" | cut -d " " -f 1)
	declare entry="$tag	$file	$sha	$relativeTarget"
	declare currentEntry
	set +e
	function grepByFile() {
		grep -E "^[^\t]+	$file" "$@" "$pulledFiles"
	}
	currentEntry=$(grepByFile)
	set -e
	declare currentVersion
	currentVersion=$(echo "$currentEntry" | perl -0777 -pe 's/([^\t]+)\t.*/$1/')

	if [ "$currentEntry" == "" ]; then
		echo "$entry" >>"$pulledFiles"
	elif ! [ "$currentVersion" == "$tag" ]; then
		printf "\033[0;36mINFO\033[0m: the file was pulled before in version %s, going to override with version %s \033[0;36m%s\033[0m\n" "$currentVersion" "$tag" "$pullDirectory/$file"
		# we could warn about a version which was older
		grepByFile -v >"$pulledFiles.new"
		mv "$pulledFiles.new" "$pulledFiles"
		echo "$entry" >>"$pulledFiles"
	else
		declare currentSha
		currentSha=$(echo "$currentEntry" | perl -0777 -pe 's/[^\t]+\t[^\t]+\t([0-9a-f]+)\t.*/$1/')
		if ! [ "$currentSha" == "$sha" ]; then
			printf "\033[1;33mWARNING\033[0m: looks like the sha512 of \033[0;36m%s\033[0m changed in tag %s\n" "$file" "$tag"
			git --no-pager diff "$(echo "$currentSha" | git hash-object -w --stdin)" "$(echo "$sha" | git hash-object -w --stdin)" --word-diff=color --word-diff-regex . | grep -A 1 @@ | tail -n +2
			printf "Won't pull the file, remove the entry from %s if you want to pull it nonetheless\n" "$pulledFiles"
			rm "$repo/$file"
			return
		elif ! grep "$entry" "$pulledFiles" >/dev/null; then
			declare currentLocation
			currentLocation=$(echo "$currentEntry" | perl -0777 -pe 's/[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)/$1/')
			printf "\033[1;33mWARNING\033[0m: the file was previously pulled to \033[0;36m%s\033[0m (new location would have been %s)\n" "$(realpath --relative-to="$currentDir" "$workingDirectory/$currentLocation")" "$pullDirectory/$file"
			printf "Won't pull the file again, remove the entry from %s if you want to pull it nonetheless\n" "$pulledFiles"
			rm "$repo/$file"
			return
		elif [ -f "$absoluteTarget" ]; then
			printf "\033[0;36mINFO\033[0m: the file was pulled before to the same location, going to override \033[0;36m%s\033[0m\n" "$pullDirectory/$file"
		fi
	fi
	mv "$repo/$file" "$absoluteTarget"

	((numberOfPulledFiles += 1))
}

while read -r -d $'\0' file; do
	if [ "$doVerification" == true ] && [ -f "$file.$sigExtension" ]; then
		printf "verifying \033[0;36m%s\033[0m\n" "$file"
		if [ -d "$pullDirectoryAbsolute/$file" ]; then
			printf >&2 "\033[1;31mERROR\033[0m: there exists a directory with the same name at %s\n" "$pullDirectoryAbsolute/$file"
			exit 1
		fi
		gpg --homedir="$gpgDir" --verify "$file.$sigExtension" "$file"
		rm "$file.$sigExtension"
		moveFile "$file"
	elif [ "$doVerification" == true ]; then
		printf "\033[1;33mWARNING\033[0m: there was no corresponding *.%s file for %s, skipping it. " "$sigExtension" "$file"
		rm "$file"
	else
		moveFile "$file"
	fi
done < <(find "$path" -type f -not -name "*.$sigExtension" -print0)

if ((numberOfPulledFiles > 0)); then
	printf "\033[1;32mSUCCESS\033[0m: %s files pulled from %s %s\n" "$numberOfPulledFiles" "$remote" "$path"
else
	printf >&2 "\033[1;31mERROR\033[0m: 0 files could be pulled from %s, most likely verification failed, see above.\n" "$remote"
	exit 1
fi
