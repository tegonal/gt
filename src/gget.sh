#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#
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
#    current_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
#
#    # Assuming gget.sh is in the same directory as your script
#    "$current_dir/gget.sh" -r tegonal-scripts -u https://github.com/tegonal/scripts \
#      -t v0.1.0 -p src/utility/update-bash-docu.sh \
#      -d "$current_dir/tegonal-scripts"
#
###################################

set -e

if ! [ -x "$(command -v "git")" ]; then
  echo >&2 "Error: git is not installed (or not in PATH), please install it (https://git-scm.com/downloads)"
  exit 1
fi

declare -A params
declare -A help

declare remote url tag path workingDirectory directory
params[remote]='-r|--remote'
help[remote]='define the name of the remote repository to use'

params[url]="-u|--url"
help[url]='define the url of the remote repository'

params[tag]='-t|--tag'
help[tag]='define which tag should be used to fetch the file'

params[path]='-p|--path'
help[path]='define which file or directory shall be fetched'

# shellcheck disable=SC2034
params[workingDirectory]='-w|--working-directory'
# shellcheck disable=SC2034
help[workingDirectory]='(optional) define a path which gget shall use as working directory -- default: .gget'

# shellcheck disable=SC2034
params[directory]='-d|--directory'
# shellcheck disable=SC2034
help[directory]='(optional) define into which directory it should be fetched -- default: .'

current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
source "$current_dir/tegonal-scripts/src/utility/parse-args.sh" || exit 123

parseArguments params "$@"
if ! [ -v workingDirectory ]; then workingDirectory=$(realpath "./.gget"); fi
if ! [ -v directory ]; then directory="."; fi
checkAllArgumentsSet params

if ! [ -d "$workingDirectory" ]; then
  echo >&2 "working directory does not exist, check for typos: $workingDirectory"
  exit 1
fi


mkdir -p "$workingDirectory" || (echo >&2 "failed to create working directory: $workingDirectory" && false)
cd "$workingDirectory"

declare repo="$workingDirectory/repos/$remote"

if ! [ -d "$repo" ]; then
  mkdir "$repo" || (echo >&2 "failed to create remote directory $repo" && false)
  cd "$repo"
  git init
fi
cd "$repo"


declare gpgHomeDir="$workingDirectory/public-keys/$remote/gpg"
mkdir -p "$gpgHomeDir"
chmod 700 "$gpgHomeDir"y

declare publicKeysDir="$workingDirectory/public-keys/$remote"

if [ "$(find "$publicKeysDir" -maxdepth 1 -name "*.asc"  | wc -l)" -eq 0 ]; then
  echo >&2 "no public keys for remote $remote defined in $publicKeysDir"
  exit 2
fi
find "$publicKeysDir" -maxdepth 1 -name "*.asc"  -exec gpg --homedir="$gpgHomeDir" --import "{}" \;


if ! [ -d "$directory" ]; then
  mkdir "$directory" || (echo >&2 "failed to create output directory $directory" && false)
fi

git init
echo "setup remote $remote using url $url"
if ! git remote | grep -q "$remote"; then
  git remote add "$remote" "$url"
else
  git remote set-url "$remote" "$url"
fi

git ls-remote -t "$remote" | grep "$tag" || (echo >&2 "remote $remote does not have a tag $tag" && git ls-remote -t "$remote" && false)

# show commands as output
set -x

git fetch --depth 1 "$remote" "refs/tags/$tag:refs/tags/$tag"
git checkout "tags/$tag" -- "$path"

# don't show commands as output anymore
{ set +x; } 2>/dev/null


declare sigExtension="sig"

if [ -f "$repo/$path" ]; then
  set -x
  # is a file, fetch also the corresponding signature
  git checkout "tags/$tag" -- "$path.$sigExtension"

  # don't show commands as output anymore
  { set +x; } 2>/dev/null
fi

find "$path" -not -name "*.$sigExtension" -type f \
  -print0 | while read -r -d $'\0' file
    do
      echo "verifying $file"
      if ! [ -f "$file.$sigExtension" ]; then
        echo >&2 "there was no corresponding *.$sigExtension file for $file"
        exit 3
      fi
      gpg --homedir="$gpgHomeDir" --verify "$file.$sigExtension" "$file"
      mkdir --parents "$directory/$file"
      mv "$file" "$directory/$file"
    done
