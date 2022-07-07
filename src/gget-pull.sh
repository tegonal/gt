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
#  'remote' command of gget: utlity to manage gget remotes
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

declare remote tag path workingDirectory
# shellcheck disable=SC2034
declare params=(
	remote '-r|--remote' 'define the name of the remote repository to use'
	tag '-t|--tag' 'define which tag should be used to pull the file/directory'
	path '-p|--path' 'define which file or directory shall be fetched'
	pullDirectory '-d|--directory' '(optional) define into which directory files of this remote will be pulled -- default: pull directory of this remote (defined during "remote add")'
	unsecure '--unsecure' '(optional) if set to true, the remote does not need to have GPG key(s) defined at .gget/*.asc -- default: false'
	workingDirectory '-w|--working-directory' '(optional) define arg path which gget shall use as working directory -- default: .gget'
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
source "$current_dir/../lib/tegonal-scripts/src/utility/parse-args.sh" || exit 200

# parsing once so that we get the workingDirectory
parseArguments params "$examples" "$@"
if ! [ -v workingDirectory ]; then workingDirectory="./.gget"; fi

# parse again in case we have default arguments for pull
if [ -f "$workingDirectory/pull.args" ]; then
	defaultArguments=$(cat "$workingDirectory/pull.args")
	declare args=()
	eval 'for arg in '"$defaultArguments"'; do
			args+=("$arg");
	done'
	parseArguments params "$examples" "${args[@]}"
fi

if ! [ -v unsecure ]; then unsecure=false; fi
checkAllArgumentsSet params "$examples"

if ! [ -d "$workingDirectory" ]; then
	printf >&2 "\033[1;31mERROR\033[0m: working directory \033[0;36m%s\033[0m does not exist\n" "$workingDirectory"
	echo >&2 "Check for typos and/or use $WORKING_DIR_PATTERN to specify another"
	exit 9
fi

# make directory paths absolute
workingDirectory=$(readlink -m "$workingDirectory")
pullDirectory=$(readlink -m "$pullDirectory")

declare remoteDirectory="$workingDirectory/$remote"
declare repo="$remoteDirectory/repo"
declare publicKeys="$remoteDirectory/public-keys"
declare gpgDir="$publicKeys/gpg"

declare doVerification=true
if ! [ -d "$gpgDir" ]; then
	printf "\033[0;36mINFO\033[0m no gpg dir in %s\nWe are going to import all public keys which are stored in %s\n" "$gpgDir" "$publicKeys"
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
		findAsc -exec gpg --homedir="$gpgDir" --import "{}" \;
	fi
fi

if ! [ -d "$pullDirectory" ]; then
	mkdir -p "$pullDirectory" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create the pull directory %s\n" "$pullDirectory" && exit 1)
fi

if [ -f "$repo" ]; then
	printf >&2 "\033[1;31mERROR\033[0m: looks like the remote \033[0;36m%s\033[0m is broken there is a file at the repo's location: %s\n" "$remote" "$remoteDirectory"
  exit 1
elif ! [ -d "$repo" ]; then
	printf "\033[0;36mINFO\033[0m repo directory does not exist for remote \033[0;36m%s\033[0m. We are going to re-initialise it based on the stored gitconfig\n" "$remote"
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

declare sigExtension="sig"

if [ "$doVerification" == "true" ] && [ -f "$repo/$path" ]; then
	set -x
	# is arg file, fetch also the corresponding signature
	git checkout "tags/$tag" -- "$path.$sigExtension"

	# don't show commands in output anymore
	{ set +x; } 2>/dev/null
fi

cd "$repo"

declare numberOfPulledFiles=0

while read -r -d $'\0' file; do
	function moveFile(){
		mkdir -p "$(dirname "$pullDirectory/$file")"
			mv "$repo/$file" "$pullDirectory/$file"
			((numberOfPulledFiles += 1))
	}

	if [ -f "$file.$sigExtension" ]; then
		printf "verifying \033[0;36m%s\033[0m\n" "$file"
		if [ -d "$pullDirectory/$file" ]; then
			printf >&2 "\033[1;31mERROR\033[0m: there exists arg directory with the same name at %s\n" "$pullDirectory/$file"
			exit 1
		fi
		gpg --homedir="$gpgDir" --verify "$file.$sigExtension" "$file"
		moveFile
	elif [ "$doVerification" == "true" ]; then
		printf "\033[1;33mWARNING\033[0m: there was no corresponding *.%s file for %s, skipping it. Disable this check via --unsecure true\n" "$sigExtension" "$file"
		rm "$file"
	else
		moveFile
	fi
done < <(find "$path" -type f -not -name "*.$sigExtension" -print0)

if ((numberOfPulledFiles > 0)); then
	printf "\033[1;32mSUCCESS\033[0m: %s files pulled from %s %s\n" "$numberOfPulledFiles" "$remote" "$path"
else
	printf >&2 "\033[1;31mERROR\033[0m: 0 files could be pulled from %s, most likely verification failed, see above.\n" "$remote"
	exit 1
fi
