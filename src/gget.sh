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
#  Utility to get a file or a directory from a public git repository.
#  Each file is verified against its signature (*.sig file) which needs to be alongside the file.
#  Corresponding public GPG keys (*.asc) need to be placed in gget's workdir (.gget by default) under WORKDIR/public-keys/<remote>
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#
#    # Assuming gget.sh is in the same directory as your script
#    "$current_dir/gget.sh" -r tegonal-scripts -u https://github.com/tegonal/scripts \
#    	-t v0.1.0 -p src/utility/update-bash-docu.sh \
#    	-d "$current_dir/tegonal-scripts"
#
###################################

set -e

if ! [ -x "$(command -v "git")" ]; then
	printf >&2 "\033[1;31mERROR\033[0m: git is not installed (or not in PATH), please install it (https://git-scm.com/downloads)\n"
	exit 100
fi


declare remote url tag path workingDirectory directory
# shellcheck disable=SC2034
declare params=(
	remote 		'-r|--remote' 'define the name of the remote repository to use'
	url 			'-u|--url' 		'define the url of the remote repository'
	tag 			'-t|--tag' 		'define which tag should be used to pull the file/directory'
	path 			'-p|--path' 	'define which file or directory shall be fetched'
	workingDirectory '-w|--working-directory' '(optional) define a path which gget shall use as working directory -- default: .gget'
	directory '-d|--directory' '(optional) define into which directory it should pull the file/directory -- default: .'
)

declare example=''

current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
source "$current_dir/tegonal-scripts/src/utility/parse-args.sh" || exit 200

parseArguments params "$example" "$@"
if ! [ -v workingDirectory ]; then workingDirectory="./.gget"; fi
if ! [ -v directory ]; then directory="."; fi
checkAllArgumentsSet params "$example"

# make directory paths absolute
workingDirectory=$(realpath "$workingDirectory")
directory=$(realpath "$directory")

if ! [ -d "$workingDirectory" ]; then
	printf >&2 "\033[1;31mERROR\033[0m: working directory does not exist, check for typos: %s\n" "$workingDirectory"
	exit 9
fi

mkdir -p "$workingDirectory" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create working directory: %s\n" "$workingDirectory" && exit 1)

declare repo="$workingDirectory/repos/$remote"

if ! [ -d "$repo" ]; then
	mkdir "$repo" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create remote directory %s\n" "$repo" && exit 1)
	cd "$repo"
	git init
	cd "$current_dir"
else
	# delete all leftovers from a previous unsuccessful pull
	find "$repo" -maxdepth 1 -type d \
		-not -path "$repo" \
		-not -path "$repo/.git" \
		-exec rm -r {} \;
fi

declare gpgHomeDir="$workingDirectory/public-keys/$remote/gpg"
mkdir -p "$gpgHomeDir"
chmod 700 "$gpgHomeDir"

declare publicKeysDir="$workingDirectory/public-keys/$remote"

if [ "$(find "$publicKeysDir" -maxdepth 1 -name "*.asc" | wc -l)" -eq 0 ]; then
	printf >&2 "\033[1;31mERROR\033[0m: no public keys for remote %s defined in %s\n" "$remote" "$publicKeysDir"
	exit 1
fi
find "$publicKeysDir" -maxdepth 1 -name "*.asc" -exec gpg --homedir="$gpgHomeDir" --import "{}" \;

if ! [ -d "$directory" ]; then
	mkdir "$directory" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create output directory %s\n" "$directory" && exit 1)
fi

cd "$repo"
echo "setup remote $remote using url $url"
if ! git remote | grep -q "$remote"; then
	git remote add "$remote" "$url"
else
	git remote set-url "$remote" "$url"
fi

git ls-remote -t "$remote" | grep "$tag" || (printf >&2 "\033[1;31mERROR\033[0m: remote %s does not have a tag %s\n" "$remote" "$tag" && git ls-remote -t "$remote" && exit 1)

# show commands as output
set -x

git fetch --depth 1 "$remote" "refs/tags/$tag:refs/tags/$tag"
git checkout "tags/$tag" -- "$path"

# don't show commands in output anymore
{ set +x; } 2>/dev/null

declare sigExtension="sig"

if [ -f "$repo/$path" ]; then
	set -x
	# is a file, fetch also the corresponding signature
	git checkout "tags/$tag" -- "$path.$sigExtension"

	# don't show commands in output anymore
	{ set +x; } 2>/dev/null
fi

cd "$repo"
find "$path" -not -name "*.$sigExtension" -type f -print0 |
	while read -r -d $'\0' file; do
		echo "verifying $file"
		if [ -f "$file.$sigExtension" ]; then
			if [ -d "$directory/$file" ]; then
				printf >&2 "\033[1;31mERROR\033[0m: there exists a directory with the same name at %s\n" "$directory/$file"
				exit 1
			fi
			gpg --homedir="$gpgHomeDir" --verify "$file.$sigExtension" "$file"
			mkdir -p "$(dirname "$directory/$file")"
			mv "$repo/$file" "$directory/$file"
		else
			printf >&2 "\033[1;33mWARNING\033[0m: there was no corresponding *.%s file for %s, skipping it\n" "$sigExtension" "$file"
		fi
	done
