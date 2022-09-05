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
	local -r msg=$1
	shift || die "could not shift by 1"
	# shellcheck disable=SC2059
	printf >&2 "\033[0;31mERROR\033[0m: $msg\n" "$@"
}

function die() {
	logError "$@"
	exit 1
}

function logSuccess() {
	local -r msg=$1
	shift || die "could not shift by 1"
	# shellcheck disable=SC2059
	printf "\033[0;32mSUCCESS\033[0m: $msg\n" "$@"
}

function checkCommandExists() {
	local -r name=$1
	local sigFile
	sigFile=$(command -v "$name") || returnDying "%s is not installed (or not in PATH) %s" "$name" "${2:-""}" || return $?
	if ! [[ -x $sigFile ]]; then
		returnDying "%s is on the system at %s (according to command) but is not executable. Consider to execute:\nsudo chmod +x %s" "$name" "$sigFile" "$sigFile" || return $?
	fi
}

function exitIfCommandDoesNotExist() {
	# we are aware of that || will disable set -e for checkCommandExists
	# shellcheck disable=SC2310
	checkCommandExists "$@" || exit $?
}

function deleteDirChmod777() {
	local -r dir=$1
	shift || die "could not shift by 1"
	# e.g files in .git will be write-protected and we don't want sudo for this command
	# yet, if it fails, then we ignore the problem and still try to delete the folder
	chmod -R 777 "$dir" || true
	rm -r "$dir"
}

exitIfCommandDoesNotExist "git"

declare projectName="gget"
declare repoUrl="https://github.com/tegonal/$projectName"
declare tmpDir
tmpDir=$(mktemp -d -t gget-install-XXXXXXXXXX)
declare gpgDir="$tmpDir/gpg"
declare repoDir="$tmpDir/repo"

function cleanup() {
	# necessary because .git files are sometime 700 and would require sudo to delete
	# we are aware of that || will disable set -e for deleteDirChmod777
	#shellcheck disable=SC2310
	deleteDirChmod777 "$tmpDir" >/dev/null 2>&1 || true
}

function install() {
	local -r tag=$1
	local -r installDir=$2
	local -r symbolicLink=$3
	shift 3 || die "could not shift by 3"

	local -r versionRegex="^(v[0-9]+)\.([0-9]+)\.[0-9]+(-RC[0-9]+)?$"
	if ! grep -Eq "$versionRegex" >/dev/null <<<"$tag"; then
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
	git remote add origin "$repoUrl" >/dev/null
	git fetch --depth=1 origin "$tag" >/dev/null
	git checkout -b "$tag" FETCH_HEAD >/dev/null

	echo "verifying the files against the current GPG key (in branch main) of $projectName"

	# we will check the chosen version against the current gpg key,
	# i.e. only if the signatures of the chosen version are still valid against the current key we are happy
	local -r publicKey="$tmpDir/signing-key.public.asc"
	wget -O- -q "https://raw.githubusercontent.com/tegonal/$projectName/main/.gget/signing-key.public.asc" >"$publicKey"

	gpg --homedir "$gpgDir" --import "$publicKey" || die "could not import public key"
	gpg --homedir="$gpgDir" --list-sig || true

	find "$repoDir" -name "*.sig" -print0 | while read -r -d $'\0' sigFile; do
		local file=${sigFile::-4}
		echo "verifying $file"
		local output
		if ! output="$(gpg --homedir="$gpgDir" --keyid-format LONG --verify "$sigFile" "$file" 2>&1)"; then
			printf "verification failed for %s:\n%s\n\n" "$sigFile" "$output"
			return 2
		fi
	done || die "verification failed, see above"

	echo "Verification complete, note that we did not verify $projectName's dependencies"
	echo ""

	if [[ -d $installDir ]]; then
		currentBranch=$(git --git-dir="$installDir/.git" rev-parse --abbrev-ref HEAD || echo "<UNKNOWN, most likely manual installation>")
		echo "Looks like $projectName was already installed in $installDir"
		printf "Current tag in use is \033[0;36m%s\033[0m\n" "$currentBranch"
		printf "going to replace the current installation with this one (%s)\n" "$tag"
		# necessary because .git files are sometime 700 and would require sudo to delete
		deleteDirChmod777 "$installDir"
		if [[ -n $symbolicLink ]]; then
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
		parent=$(dirname "$symbolicLink")
		mkdir -p "$parent"
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

function exitIfValueMissing() {
	[[ -n "${2:-}" ]] || die "only %s provided but not a corresponding value" "$1"
}

function main() {
	local tag=""
	local installDir=""
	local symbolicLink=""

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
		echo "determine latest tag of $repoUrl"
		tag=$(git ls-remote --refs --tags "$repoUrl" |
			cut --delimiter='/' --fields=3 |
			sort --version-sort |
			tail --lines=1)
	fi
	if [[ -z $installDir && -n $symbolicLink ]]; then
		die "you can only specify a symbolic link if you specify a custom installation directory."
	fi
	if [[ -z $installDir ]]; then
		prefix=$(readlink -m "$HOME/.local")
		installDir="$prefix/lib/$projectName"
		symbolicLink="$prefix/bin/$projectName"
		echo "using default installation directory ($installDir) and symbolic link ($symbolicLink), use --directory and --ln to specify custom values"
	fi
	installDir=$(readlink -m "$installDir")
	# if symbolicLink is relative, then make it absolute using pwd
	if [[ -n $symbolicLink && $symbolicLink != /* ]]; then
		symbolicLink="$(pwd)/$symbolicLink"
	fi

	install "$tag" "$installDir" "$symbolicLink"
}
main "$@"
