#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.3.0-SNAPSHOT
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

function logError() {
	local msg=$1
	shift || die "could not shift by 1"
	# shellcheck disable=SC2059
	printf >&2 "\033[0;31mERROR\033[0m: $msg\n" "$@"
}

function die() {
	logError "$@"
	exit 1
}

function logSuccess() {
	local msg=$1
	shift || die "could not shift by 1"
	# shellcheck disable=SC2059
	printf "\033[0;32mSUCCESS\033[0m: $msg\n" "$@"
}

function checkCommandExists() {
	local name=$1
	file=$(command -v "$name") || die "%s is not installed (or not in PATH) %s" "$name" "${2:-""}"
	if ! [[ -x $file ]]; then
		die "%s is on the system at %s (according to command) but cannot be executed" "$name" "$file"
	fi
}

function exitIfCommandDoesNotExist() {
	# we are aware of that || will disable set -e for checkCommandExists
	# shellcheck disable=SC2310
	checkCommandExists "$@" || exit $?
}

function deleteDirChmod777() {
	local dir=$1
	shift || die "could not shift by 1"
	# e.g files in .git will be write-protected and we don't want sudo for this command
	# yet, if it fails, then we ignore the problem and still try to delete the folder
	chmod -R 777 "$dir" || true
	rm -r "$dir"
}

exitIfCommandDoesNotExist "git"

projectName="gget"
repo="https://github.com/tegonal/$projectName"
tmpDir="${TMPDIR:-${TMP:-/tmp}}/${projectName}_installation"
gpgDir="$tmpDir/gpg"
repoDir="$tmpDir/repo"

function cleanup() {
	# necessary because .git files are sometime 700 and would require sudo to delete
	# we are aware of that || will disable set -e for deleteDirChmod777
	#shellcheck disable=SC2310
	deleteDirChmod777 "$tmpDir" >/dev/null 2>&1 || true
}

function install() {
	tag=$1
	installDir=$2
	symbolicLink=$3
	shift 3 || die "could not shift by 3"

	versionRegex="^(v[0-9]+)\.([0-9]+)\.[0-9]+(-RC[0-9]+)?$"
	if ! echo "$tag" | grep -Eq "$versionRegex" >/dev/null; then
		die "tag needs to follow the regex %s -- given %s" "$versionRegex" "$tag"
	fi

	cleanup

	mkdir -p "$gpgDir"
	chmod 700 "$gpgDir"
	mkdir -p "$repoDir"

	trap cleanup EXIT

	echo "downloading $projectName $tag"

	cd "$repoDir"
	git init >/dev/null
	git remote add origin "$repo" >/dev/null
	git fetch --depth=1 origin "$tag" >/dev/null
	git checkout -b "$tag" FETCH_HEAD >/dev/null

	echo "verifying the files against the current GPG key (in branch main) of $projectName"

	# we will check the chosen version against the current gpg key,
	# i.e. only if the signatures of the chosen version are still valid against the current key we are happy
	publicKey="$tmpDir/signing-key.public.asc"
	wget -O- -q "https://raw.githubusercontent.com/tegonal/$projectName/main/.gget/signing-key.public.asc" >"$publicKey"

	gpg --homedir "$gpgDir" --import "$publicKey"
	gpg --homedir="$gpgDir" --list-sig

	find "$repoDir" -name "*.sig" -print0 |
		xargs -0 -I {} sh -c "file=\"\$(echo '{}' | rev | cut -c5- | rev)\"; echo \"verifying \$file\"; output=\"\$(gpg --homedir='$gpgDir' --keyid-format LONG --verify \"\$file.sig\" \"\$file\" 2>&1)\"; if ! [ \"\$?\" -eq 0 ]; then printf \"verification failed for %s:\n%s\n\n\" \"\$file\" \"\$output\"; exit 2; fi" || die "verication failed, see above"

	echo "Verification complete, note that we did not verify $projectName's dependencies"
	echo ""

	if [[ -d $installDir ]]; then
		currentBranch=$(git --git-dir="$repoDir/.git" rev-parse --abbrev-ref HEAD || echo "<UNKNOWN, most likely manual installation>")
		echo "Looks like $projectName was already installed in $installDir. Current tag in use is $currentBranch"
		echo "going to replace the current installation with the new one"
		# necessary because .git files are sometime 700 and would require sudo to delete
		deleteDirChmod777 "$installDir"
		if [[ -n "$symbolicLink" ]]; then
			rm "$symbolicLink" >/dev/null 2>&1 || true
		fi
	fi
	local parent
	parent=$(dirname "$installDir")
	mkdir -p "$parent"
	mv "$repoDir" "$installDir"

	echo "moved sources to installation directory $installDir"

	if [[ -n $symbolicLink ]]; then
		echo "set up symbolic link $symbolicLink"
		ln -sf "$installDir/src/$projectName.sh" "$symbolicLink" || sudo ln -sf "$installDir/src/$projectName.sh" "$symbolicLink"
	else
		echo "no symbolic link set up, please do manually if required"
	fi
	logSuccess "installation completed, $projectName set up in %s" "$installDir"
	if [[ -n $symbolicLink ]]; then
		echo ""
		echo "Testing the symbolic link, following the output of calling $projectName --help"
		echo ""
		"$projectName" --help
	fi
}

tag=""
installDir=""
symbolicLink=""

function exitIfValueMissing() {
	[[ -n "${2:-}" ]] || die "only %s provided but not a corresponding value" "$1"
}

while [[ $# -gt 0 ]]; do
	case $1 in
	-t | --tag)
		exitIfValueMissing "$@"
		tag=$2 && shift
		;;
	-d | --directory)
		exitIfValueMissing "$@"
		installDir=$2 && shift
		;;
	-ln)
		exitIfValueMissing "$@"
		symbolicLink=$2 && shift
		;;
	-*) die "unknown option $1" ;;
	*) die "unknown argument $1" ;;
	esac
	shift
done

if [[ -z $tag ]]; then
	echo "determine latest tag of $repo"
	tag=$(git ls-remote --refs --tags "$repo" |
		cut --delimiter='/' --fields=3 |
		tr '-' '~' |
		sort --version-sort |
		tail --lines=1)
fi
if [[ -z $installDir ]] && [[ -n $symbolicLink ]]; then
	die "you can only specify a symbolic link if you specify a custom installation directory."
fi
if [[ -z $installDir ]]; then
	prefix=$(readlink -m "$HOME/.local")
	installDir="$prefix/lib/$projectName"
	symbolicLink="$prefix/bin/$projectName"
	echo "configuring default installation directory ($installDir) and symbolic link ($symbolicLink)"
fi
installDir=$(readlink -m "$installDir")
# if symbolicLink is relative, then make it absolute using pwd
if [[ $symbolicLink != /* ]]; then
	symbolicLink="$(pwd)/$symbolicLink"
fi

install "$tag" "$installDir" "$symbolicLink"
