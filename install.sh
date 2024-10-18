#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.20.0-SNAPSHOT
#######  Description  #############
#
#  installation script which downloads and set ups the latest or a specific tag of gt
#
#######  Usage  ###################
#
#    currentDir=$(pwd) && \
#    tmpDir=$(mktemp -d -t gt-download-install-XXXXXXXXXX) && cd "$tmpDir" && \
#    wget "https://raw.githubusercontent.com/tegonal/gt/main/.gt/signing-key.public.asc" && \
#    wget "https://raw.githubusercontent.com/tegonal/gt/main/.gt/signing-key.public.asc.sig" && \
#    gpg --verify ./signing-key.public.asc.sig ./signing-key.public.asc && \
#    echo "public key trusted" && \
#    mkdir ./gpg && \
#    gpg --homedir ./gpg --import ./signing-key.public.asc && \
#    wget "https://raw.githubusercontent.com/tegonal/gt/v0.19.0/install.sh" && \
#    wget "https://raw.githubusercontent.com/tegonal/gt/v0.19.0/install.sh.sig" && \
#    gpg --homedir ./gpg --verify ./install.sh.sig ./install.sh && \
#    chmod +x ./install.sh && \
#    echo "verification successful" || (printf >&2 "\033[0;31mERROR\033[0m: verification failed, don't continue !!"; exit 1) && \
#    ./install.sh && result=true || (echo >&2 "installation failed"; exit 1) && \
#    false || cd "$currentDir" && rm -r "$tmpDir" && "${result:-false}"
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

function logError() {
	local -r msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	# shellcheck disable=SC2059
	printf >&2 "\033[0;31mERROR\033[0m: $msg\n" "$@"
}

function die() {
	logError "$@"
	exit 1
}

function logSuccess() {
	local -r msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	# shellcheck disable=SC2059
	printf "\033[0;32mSUCCESS\033[0m: $msg\n" "$@"
}

function logInfo() {
	local msg=$1
	shift 1 || traceAndDie "could not shift by 1"
	# shellcheck disable=SC2059
	printf "\033[0;34mINFO\033[0m: $msg\n" "$@"
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
	# shellcheck disable=SC2310 	# we are aware of that || will disable set -e for checkCommandExists
	checkCommandExists "$@" || exit $?
}

function deleteDirChmod777() {
	local -r dir=$1
	shift 1 || traceAndDie "could not shift by 1"
	# e.g files in .git will be write-protected and we don't want sudo for this command
	# yet, if it fails, then we ignore the problem and still try to delete the folder
	chmod -R 777 "$dir" || true
	rm -r "$dir"
}

exitIfCommandDoesNotExist "git"

declare projectName="gt"
declare repoUrl="https://github.com/tegonal/$projectName"
declare tmpDir
tmpDir=$(mktemp -d -t gt-install-XXXXXXXXXX)
declare gpgDir="$tmpDir/gpg"
declare repoDir="$tmpDir/repo"

function cleanup() {
	# necessary because .git files are sometime 700 and would require sudo to delete

	#shellcheck disable=SC2310		# we are aware of that || will disable set -e for deleteDirChmod777
	deleteDirChmod777 "$tmpDir" >/dev/null 2>&1 || true
}

function install() {
	local -r tag=$1
	local -r installDir=$2
	local -r symbolicLink=$3
	shift 3 || traceAndDie "could not shift by 3"

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
	wget -O "$publicKey" -q "https://raw.githubusercontent.com/tegonal/$projectName/main/.gt/signing-key.public.asc" || die "could not fetch public key from main branch"

	gpg --homedir "$gpgDir" --import "$publicKey" || die "could not import public key"
	gpg --homedir "$gpgDir" --list-sig || true

  # TODO remove .gget with 1.0.0
	find "$repoDir" \
	  -type f \
		-name "*.sig" \
		-not -path "$repoDir/.gt/signing-key.public.asc.sig" \
		-not -path "$repoDir/.gt/remotes/*/public-keys/*.sig" \
		-not -path "$repoDir/.gget/signing-key.public.asc.sig" \
		-not -path "$repoDir/.gget/remotes/*/public-keys/*.sig" \
		-print0 |
		while read -r -d $'\0' sigFile; do
			local file=${sigFile::-4}
			echo "verifying $file"
			local output
			if ! output="$(gpg --homedir "$gpgDir" --keyid-format LONG --verify "$sigFile" "$file" 2>&1)"; then
				printf "verification failed for %s:\n%s\n\n" "$file" "$output"
				return 2
			fi
		done || die "verification failed, see above"

	echo "Verification complete, note that we did not verify $projectName's dependencies"
	echo ""

	if [[ -d $installDir ]]; then
		currentBranch=$(git --git-dir="$installDir/.git" rev-parse --abbrev-ref HEAD || echo "<UNKNOWN, most likely manual installation>")
		echo "Looks like $projectName was already installed in $installDir"
		printf "Current tag in use is \033[0;36m%s\033[0m\n" "$currentBranch"
		printf "going to replace the current installation with the chosen \033[0;36m%s\033[0m\n" "$tag"
		# necessary because .git files are sometimes mod 700 and would require sudo to delete
		deleteDirChmod777 "$installDir"
		if [[ -n $symbolicLink ]]; then
			rm "$symbolicLink" >/dev/null 2>&1 || true
		fi
	fi
	local parent
	parent=$(dirname "$installDir")
	mkdir -p "$parent"
	mv "$repoDir" "$installDir"

	logInfo "moved sources to installation directory $installDir"

	if [[ -n $symbolicLink ]]; then
		logInfo "set up symbolic link $symbolicLink"
		parent=$(dirname "$symbolicLink")
		mkdir -p "$parent"
		ln -sf "$installDir/src/$projectName.sh" "$symbolicLink" || sudo ln -sf "$installDir/src/$projectName.sh" "$symbolicLink"
	else
		logInfo "no symbolic link set up, please do manually if required"
	fi
	logSuccess "installation completed, %s %s set up in %s" "$projectName" "$tag" "$installDir"
	if [[ -n $symbolicLink ]]; then
		echo ""
		logInfo "Testing the symbolic link, following the output of calling $projectName --help"
		echo ""
		"$projectName" --help
		echo ""
		logSuccess "looks like it worked"
	fi

	local fpath_output
	fpath_output=$(zsh -c 'echo $fpath') || echo ""
	if [[ -n "$fpath_output" ]]; then
		local vendorPath
		vendorPath=$(grep -oE "[^ ]+vendor-completions" <<<"$fpath_output")
		if [[ -n $vendorPath ]]; then
			logInfo "determined zsh, trying to add it to %s via sudo" "$vendorPath"
			sudo -k cp "$installDir/src/install/zsh/_gt" "$vendorPath"
			logSuccess "copied zsh completion into %s" "$vendorPath"
		fi
	fi

	logSuccess "thank you for using gt, please report bugs"
}

function exitIfValueMissing() {
	[[ -n "${2:-}" ]] || die "only %s provided but not a corresponding value" "$1"
}

function parseError() {
	die "unknown $1 $2\nHelp:
	-t|--tag        (optional) the tag which shall be installed -- default: latest
	-d|--directory  (optional) the installation directory -- default: \$HOME/.local/lib and
	-ln             (optional) the path of a symbolic link which shall be set up -- default: \$HOME/.local/bin/gt if directory is not set otherwise nothing in which case no symbolic link is setup"
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
		-*) parseError "option" "$1" ;;
		*) parseError "argument" "$1" ;;
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
		if [[ -z $symbolicLink ]]; then
			symbolicLink="$prefix/bin/$projectName"
		fi
		echo "using default installation directory ($installDir) and symbolic link ($symbolicLink), use --directory and --ln to specify custom values"
	fi
	installDir=$(readlink -m "$installDir")
	# if symbolicLink is relative, then make it absolute using pwd
	if [[ -n $symbolicLink && $symbolicLink != /* ]]; then
		local currentDir
		currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
		local -r currentDir
		symbolicLink="$currentDir/$symbolicLink"
	fi

	install "$tag" "$installDir" "$symbolicLink"
}
if [[ "$EUID" -eq 0 ]]; then
	die "don't run the installation as super user"
fi
main "$@"
