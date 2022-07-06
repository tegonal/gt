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
#    current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#
#    # Assuming gget-remote.sh is in the same directory as your script -- though, usually you would use: gget remote ...
#
#    # adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
#    "$current_dir/gget-remote.sh" add -r tegonal-scripts -u https://github.com/tegonal/scripts
#
#    # lists all existing remotes
#    "$current_dir/gget-remote.sh" list
#
#    # removes the remote tegonal-scripts again
#    "$current_dir/gget-remote.sh" remove -r tegonal-scripts
#
###################################

set -e

declare current_dir
current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
source "$current_dir/tegonal-scripts/src/utility/parse-args.sh" || exit 200

declare DEFAULT_WORKING_DIR='.gget'
declare WORKING_DIR_PATTERN='-w|--working-directory'

function add() {

	declare remote url directory workingDirectory unsecure
	# shellcheck disable=SC2034
	declare params=(
		remote '-r|--remote' 'define the name of the remote repository to use'
		url '-u|--url' 'define the url of the remote repository'
		directory '-d|--directory' '(optional) define into which directory files of this remote will be pulled -- default: ./lib/<remote>'
		unsecure '--unsecure' '(optional) if set to true, the remote does not need to have GPG key(s) defined at .gget/*.asc -- default: false'
		workingDirectory "$WORKING_DIR_PATTERN" '(optional) define a path which gget shall use as working directory -- default: .gget'
	)
	declare example=''
	parseArguments params "$example" "$@"
	if ! [ -v directory ]; then directory="./lib/$remote"; fi
	if ! [ -v unsecure ]; then unsecure=false; fi
	if ! [ -v workingDirectory ]; then workingDirectory="$DEFAULT_WORKING_DIR"; fi
	checkAllArgumentsSet params "$example"

	# make directory paths absolute
	workingDirectory=$(readlink -m "$workingDirectory")
	directory=$(readlink -m "$directory")

	mkdir -p "$workingDirectory"

	declare remoteDirectory="$workingDirectory/$remote"

	if [ -f "$remoteDirectory" ]; then
		printf >&2 "\033[1;31mERROR\033[0m: cannot create remote directory, there is a file at this location: %s\n" "$remoteDirectory"
		exit 9
	elif [ -d "$remoteDirectory" ]; then
		printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m already exists, remove with: gget remote remove %s\n" "$remote" "$remote"
		exit 9
	fi

	mkdir -p "$directory"

	mkdir "$remoteDirectory" || (printf >&2 "\033[1;31mERROR\033[0m: failed to create remote directory %s\n" "$remoteDirectory" && exit 1)
	declare publicKeys="$remoteDirectory/public-keys"
	mkdir "$publicKeys"
	declare repo="$remoteDirectory/repo"
	mkdir "$repo"
	cd "$repo"

	# show commands in output
	set -x
	git init
	git remote add "$remote" "$url"

	declare defaultBranch
	defaultBranch="$(git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"

	git fetch --depth 1 "$remote" "$defaultBranch"

	# don't show commands in output anymore
	{ set +x; } 2>/dev/null

	set +e
	git checkout "$remote/$defaultBranch" -- '.gget'
	local checkoutResult=$?
	set -e
	if ! ((checkoutResult == 0)); then
		if [ "$unsecure" == true ]; then
			printf "\033[1;33mWARNING\033[0m: no GPG key found, ignoring it because --unsecure true was specified\n"
			exit 0
		else
			printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m has no directory \033[0;36m.gget\033[0m defined in branch \033[0;36m%s\033[0m, unable to fetch the GPG key(s)\n" "$remote" "$defaultBranch"
			exit 1
		fi
	fi

	declare findAsc='find ".gget" -maxdepth 1 -name "*.asc"'
	if (($(eval "$findAsc" | wc -l) == 0)); then
		printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m has a directory \033[0;36m.gget\033[0m but no GPG key ending in *.asc defined in it\n" "$remote"
		exit 1
	fi

	eval "$findAsc -exec mv {} \"$publicKeys\" \;"
	rm -r ".gget"
	cd "$publicKeys"
	declare gpgDir="$publicKeys/gpg"
	mkdir "$gpgDir"
	chmod 700 "$gpgDir"
	echo ""
	declare numberOfImportedKeys=0

	declare tmpFile
	tmpFile=$(mktemp /tmp/gget.XXXXXXXXX)
	exec 3>"$tmpFile"
	exec 4<"$tmpFile"
	rm "$tmpFile"

	find "$publicKeys" -name "*.asc" -type f -print0 >&3

	while read -u 4 -r -d $'\0' file; do
		declare outputKey
		outputKey=$(gpg --keyid-format LONG --import-options show-only --import "$file")
		echo "$outputKey"
		printf "\n\033[0;36mThe above key(s) will be used to verify the files you will pull from this remote, do you trust it?\033[0m y/[N]:"
		while read -r isTrusting; do
			break
		done
		echo ""
		echo "Decision: $isTrusting"
		if [ "$isTrusting" == "y" ]; then
			echo "importing key $file"
			gpg --homedir "$gpgDir" --import "$file"
			echo "$outputKey" | grep pub | perl -0777 -pe "s#pub\s+[^/]+/([0-9A-Z]+).*#\$1#g" |
				while read -r keyId; do
					echo -e "5\ny\n" | gpg --homedir "$gpgDir" --command-fd 0 --edit-key "$keyId" trust
				done
			((numberOfImportedKeys += 1))
		else
			echo "deleting key $file"
			rm "$file"
		fi
	done
	exec 3>&-
	exec 4<&-

	if ((numberOfImportedKeys == 0)); then
		if [ "$unsecure" == true ]; then
			printf "\033[1;33mWARNING\033[0m: no GPG keys imported, ignoring it because --unsecure true was specified\n"
			exit 0
		else
			printf >&2 "\033[1;31mERROR\033[0m: no GPG keys imported, you won't be able to pull files from the remote \033[0;36m%s\033[0m without using --unsecure true\n" "$remote"
			exit 1
		fi
	fi

	gpg --homedir "$gpgDir" --list-sig
	echo "Imported $numberOfImportedKeys GPG key(s) successfully, you are ready to pull files via: gget pull -r $remote ..."
}

function remove() {
	declare workingDirectory
	# shellcheck disable=SC2034
	local params=(
		remote '-r|--remote' 'define the name of the remote which shall be removed'
		workingDirectory '-w|--working-directory' '(optional) define a path which gget shall use as working directory -- default: .gget'
	)
	parseArguments params "$example" "$@"
	if ! [ -v workingDirectory ]; then workingDirectory="$DEFAULT_WORKING_DIR"; fi
	checkAllArgumentsSet params "$example"

	declare remoteDirectory="$workingDirectory/$remote"

	if [ -f "$remoteDirectory" ]; then
		printf >&2 "\033[1;31mERROR\033[0m: cannot delete remote \033[0;36m%s\033[0m, looks like it is broken there is a file at this location: %s\n" "$remote" "$remoteDirectory"
		exit 9
	elif ! [ -d "$remoteDirectory" ]; then
		printf >&2 "\033[1;31mERROR\033[0m: remote \033[0;36m%s\033[0m does not exist, check for typos\n" "$remote"
		exit 9
	fi

	# because files in .git will be write-protected and we don't want sudo for this command
	chmod -R 777 "${workingDirectory}/$remote"
	rm -r "${workingDirectory:?}/$remote"
	printf "Removed remote \033[0;36m%s\033[0m" "$remote"
}

function list() {
	declare workingDirectory
	# shellcheck disable=SC2034
	local params=(
		workingDirectory '-w|--working-directory' '(optional) define a path which gget shall use as working directory -- default: .gget'
	)
	parseArguments params "$example" "$@"
	if ! [ -v workingDirectory ]; then workingDirectory="$DEFAULT_WORKING_DIR"; fi
	checkAllArgumentsSet params "$example"

	if ! [ -d "$workingDirectory" ]; then
		printf >&2 "\033[1;31mERROR\033[0m: working directory %s does not exist\n" "$workingDirectory"
		echo >&2 "Check for typos and/or use $WORKING_DIR_PATTERN to specify another"
		exit 9
	fi

	cd "$workingDirectory"
	local output
	output="$(find . -maxdepth 1 -type d -not -path "." | cut -c 3-)"
	if [ "$output" == "" ]; then
		printf "\033[1;33mNo remote define yet.\033[0m\n"
		echo "To add one, use: gget remote add ..."
		echo "Following the corresponding documentation of the parameters:"
		add "--help"
	else
		echo "$output"
	fi
}

if [[ $# -lt 1 ]]; then
	printf >&2 "\033[1;31mERROR\033[0m: At least one parameter needs to be passed\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
	echo >&2 '1. command     one of: add, remove, list'
	echo >&2 '2... args...   command specific arguments'
	exit 9
fi

declare command=$1
shift
if [[ "$command" =~ ^(add|remove|list)$ ]]; then
	"$command" "$@"
elif [[ "$command" == "--help" ]]; then
	cat <<-EOM

		Use one of the following commands:
		add      add a remote
		remove   remove a remote
		list     list all existing remotes
	EOM
else
	printf >&2 "\033[1;31mERROR\033[0m: unknown command %s, expected one of add, list, remove\n" "$command"
	exit 9
fi
