#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.7.0-SNAPSHOT
#######  Description  #############
#
#  installation script which downloads and set ups the latest or a specific tag of gt
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    currentDir=$(pwd) &&
#    	tmpDir=$(mktemp -d -t gt-download-install-XXXXXXXXXX) && cd "$tmpDir" &&
#    	wget "https://raw.githubusercontent.com/tegonal/gt/main/.gt/signing-key.public.asc" &&
#    	wget "https://raw.githubusercontent.com/tegonal/gt/main/.gt/signing-key.public.asc.sig" &&
#    	gpg --verify ./signing-key.public.asc.sig ./signing-key.public.asc &&
#    	echo "public key trusted" &&
#    	mkdir ./gpg &&
#    	gpg --homedir ./gpg --import ./signing-key.public.asc &&
#    	wget "https://raw.githubusercontent.com/tegonal/gt/v1.6.3/install.sh" &&
#    	wget "https://raw.githubusercontent.com/tegonal/gt/v1.6.3/install.sh.sig" &&
#    	gpg --homedir ./gpg --verify ./install.sh.sig ./install.sh &&
#    	chmod +x ./install.sh &&
#    	echo "verification successful" ||
#    	{
#    		printf >&2 "\033[0;31mERROR\033[0m: verification failed, don't continue !!\n"
#    		exit 1
#    	} && ./install.sh && result=true ||
#    	{
#    		echo >&2 "installation failed"
#    		exit 1
#    	} && false || cd "$currentDir" && rm -r "$tmpDir" && "${result:-false}"
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v location_of_install_sh ]]; then
	location_of_install_sh="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly location_of_install_sh
fi

function logError() {
	local -r msg=$1
	shift 1 || die "Could not shift by 1"
	# shellcheck disable=SC2059
	printf >&2 "\033[0;31mERROR\033[0m: $msg\n" "$@"
}

function die() {
	logError "$@"
	exit 1
}

function logSuccess() {
	local -r msg=$1
	shift 1 || die "could not shift by 1"
	# shellcheck disable=SC2059
	printf "\033[0;32mSUCCESS\033[0m: $msg\n" "$@"
}

function logInfo() {
	local -r msg=$1
	shift 1 || die "could not shift by 1"
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
	checkCommandExists "$@" || exit $?
}

function deleteDirChmod777() {
	local -r dir=$1
	shift 1 || die "could not shift by 1"
	# e.g files in .git will be write-protected and we don't want sudo for this command
	# yet, if it fails, then we ignore the problem and still try to delete the folder
	chmod -R 777 "$dir" || true
	rm -r "$dir"
}

declare projectName="gt"
declare repoUrl="https://github.com/tegonal/$projectName"
declare tmpDir
tmpDir=$(mktemp -d -t gt-install-XXXXXXXXXX)
declare gpgDir="$tmpDir/gpg"
declare tmpLibDir="$tmpDir/bin"
declare bakDir="$tmpDir/bak"

function cleanup() {
	# necessary because .git files are sometime 700 and would require sudo to delete

	deleteDirChmod777 "$tmpDir" >/dev/null 2>&1 || true
}

function determinePackage() {
	local -r tag=$1
	local os arch
	os=$(uname -s)
	arch=$(uname -m)

	case "$os" in
	Linux)
		os="unknown-linux-gnu"
		;;
	Darwin)
		os="apple-darwin"
		;;
	MINGW* | MSYS* | CYGWIN*)
		os="pc-windows-msvc"
		;;
	*)
		die "Unsupported os: $os -- please open a feature request at https://github.com/tegonal/gt/discussions/new?category=ideas&title=Support%20for%20OS%20$os"
		;;
	esac

	case "$arch" in
	x86_64)
		arch="x86_64"
		;;
	arm64)
		arch="aarch64"
		;;
	*)
		die "Unsupported architecture: $arch -- please open a feature request at https://github.com/tegonal/gt/discussions/new?category=ideas&title=Support%20for%20arch%20$arch"
		;;
	esac

	echo"gt-${arch}-${os}"
}

function download() {
	local -r url=$1
	local -r target=$1
	if command -v wget >/dev/null; then
		wget --https-only --secure-protocol=TLSv1_2 -O "$target" -q "$url" || die "could not fetch $target from $url"
	else
		# if wget does not exist, then we try it with curl
		curl --proto '=https' --tlsv1.2 -fL -o "$target" -s "$url" || die "could not fetch $target from $url"
	fi
}

function install() {
	local -r tag=$1
	local -r installDir=$2
	local -r symbolicLink=$3
	shift 3 || die "could not shift by 3"

	local -r versionRegex="^(v[2-9]+)\.([0-9]+)\.[0-9]+(-RC[0-9]+)?$"
	if ! grep -Eq "$versionRegex" >/dev/null <<<"$tag"; then
		if grep -Eq "[0-1]\.([0-9]+)\.[0-9]+(-RC[0-9]+)?"; then
			die "Version 0 and 1 can no longer be installed. Use an older version of install.sh if you want to install the bash based version of gt"
		else
			die "tag needs to follow the regex %s -- given %s" "$versionRegex" "$tag"
		fi
	fi

	mkdir -p "$gpgDir"
	chmod 700 "$gpgDir"
	mkdir -p "$tmpLibDir"

	trap cleanup EXIT

	logInfo "downloading $projectName $tag"

	cd "$tmpLibDir"
	local binaryName binary
	binaryName="$(determinePackage)"
	binary="$tmpLibDir/$binaryName"

	local -r publicKey="$tmpDir/signing-key.public.asc"
	logInfo "Verifying the binary and latest install.sh against the current GPG key (in branch main) of $projectName (assuming you trusting this key)"
	# we will check the chosen version against the current gpg key,
	# i.e. only if the signature of the chosen version are still valid against the current key we are happy
	download "https://raw.githubusercontent.com/tegonal/$projectName/main/.gt/signing-key.public.asc" "$publicKey"
	gpg --homedir "$gpgDir" --import "$publicKey" || die "could not import public key"
	gpg --homedir "$gpgDir" --list-sig || true

	# downloading the latest installer, regardless of the installer we currently use, so that the self-update works well
	download "https://raw.githubusercontent.com/tegonal/$projectName/main/install.sh" "$tmpLibDir/install.sh"
	download "https://raw.githubusercontent.com/tegonal/$projectName/main/install.sh.sig" "$tmpLibDir/install.sh.sig"
	download "https://github.com/tegonal/gt/releases/download/$tag/$binaryName" "$binary"
	download "https://github.com/tegonal/gt/releases/download/$tag/$binaryName.sig" "$binary.sig"

	local previousKeyId=""

	find "$tmpLibDir" \
		-type f \
		-name "*.sig" \
		-print0 |
		while read -r -d $'\0' sigFile; do
			local file=${sigFile::-4}
			echo "Verifying $file"
			local output
			if ! output="$(gpg --homedir "$gpgDir" --keyid-format LONG --verify "$sigFile" "$file" 2>&1)"; then
				printf "Verification failed for %s:\n%s\n\n" "$file" "$output"
				return 2
			else
				local sigPackets keyId
				sigPackets=$(gpg --list-packets "$sigFile") || returnDying "Could not list-packets for %s" "$sigFile" || return $?
				keyId=$(grep -oE "keyid .*" <<<"$sigPackets" | cut -c7-) || returnDying "Could not extract keyid from signature packets:\n%s" "$sigPackets" || return $?
				if [[ $previousKeyId != "$keyId" ]]; then
					previousKeyId="$keyId"
					local keyData
					keyData=$(
						gpg --homedir "$gpgDir" --list-keys \
							--list-options show-sig-expire,show-unusable-subkeys,show-unusable-uids \
							--with-colons "$keyId" | grep -E "^(pub|sub).*$keyId"
					) || returnDying "Was not able to extract the key data for %s" "$keyId" || return $?
					if grep -E '^(sub|pub):r:' <<<"$keyData" >/dev/null; then
						logError "Key %s which signed the files of tag %s was revoked, aborting installation" "$keyId" "$tag"
						return 3
					else
						echo "Verified that key %s which signed files is not revoked" "$keyId"
					fi
				fi
			fi
		done || die "Verification failed, see above"

	logInfo "Verification complete"
	echo ""

	## check if it works before we remove maybe an older installation
	"$binary" --version || die "Could not run $binary, aborting"

	if [[ -d $installDir ]]; then
		mv "$installDir" "$bakDir"
		echo "Looks like $projectName was already installed in $installDir (the directory exists) -- moved it to the backup dir $bakDir"
		printf "Going to replace the current installation with the chosen \033[0;36m%s\033[0m\n" "$tag"
		if [[ -n $symbolicLink ]]; then
			rm "$symbolicLink" >/dev/null 2>&1 || true
		fi
	fi
	local parent
	parent=$(dirname "$installDir")
	mkdir -p "$parent"
	mv "$tmpLibDir" "$installDir"

	logInfo "Moved files to installation directory $installDir"

	if [[ -n $symbolicLink ]]; then
		logInfo "set up symbolic link $symbolicLink"
		parent=$(dirname "$symbolicLink")
		mkdir -p "$parent"
		ln -sf "$installDir/$binaryName" "$symbolicLink" || sudo ln -sf "$installDir/$binaryName" "$symbolicLink"
	else
		logInfo "no symbolic link set up, please do manually if required"
	fi
	logSuccess "installation completed, %s %s set up in %s" "$projectName" "$tag" "$installDir"

	if [[ -d $bakDir ]]; then
		logInfo "removing the backup dir in %s" "$bakDir"
		# necessary because .git files (in the bash-based gt version we checked out the repo)
		# are sometimes mod 700 and would require sudo to delete
		deleteDirChmod777 "$bakDir"
	fi

	local fpath_output
	fpath_output=$(zsh -c 'echo $fpath' 2>/dev/null) || echo ""

	if [[ -n "$fpath_output" ]]; then
		local vendorPath
		vendorPath=$(grep -oE "[^ ]+vendor-completions" <<<"$fpath_output")
		if [[ -n $vendorPath ]]; then
			logInfo "determined zsh, trying to add it to %s via sudo" "$vendorPath"
			local gtCompletion="$installDir/src/install/zsh/_gt"
			if sudo -k cp "$gtCompletion" "$vendorPath"; then
				# reload compinit to activate the gt completion without the need to re-open the terminal
				(autoload -Uz compinit && compinit) || logInfo "autoload compinit failed, you need to close and re-open your terminal in order to get the gt code completion functionality working"
				logSuccess "copied zsh completion into %s" "$vendorPath"
			else
				logError "was not able to copy %s into %s -- do it manually if you want" "$gtCompletion" "$vendorPath"
			fi
		fi
	fi

	if [[ -n $symbolicLink ]]; then
		echo ""
		logInfo "Testing the symbolic link, following the output of calling $projectName --help"
		echo ""
		if "$projectName" --help; then
			echo ""
			logSuccess "looks like it worked"
		else
			local symlinkDir homeLocalBin
			symlinkDir=$(dirname "$symbolicLink")
			homeLocalBin=$(readlink -m "$HOME/.local/bin")

			# trying to help the user why the installation failed
			if [[ -n "$fpath_output" && $symlinkDir == "$homeLocalBin" ]]; then
				echo ""
				logError "looks like something went wrong. You seem using zsh and the parent directory of the symlink (%s) is a typical BASH location.\nMake sure you have added it to your PATH in your .zshrc -- i.e. add the following if it is missing:\nexport PATH=\"\$PATH:\$HOME/.local/bin\"\n\nFollowing the current PATH:\n%s" "$symlinkDir" "$PATH"
				echo ""
			else
				logError "looks like something is wrong, make sure %s is in your PATH and try again. Following the PATH:\n%s" "$symlinkDir" "$PATH"
			fi
			exit 1
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
	-ln             (optional) the path of a symbolic link which shall be set up -- default: \$HOME/.local/bin/gt if directory is not set otherwise nothing in which case no symbolic link is setup
	--root				  (optional) if you explicitly want to run it as root"
}

function main() {
	local tag=""
	local installDir=""
	local symbolicLink=""
	local asRoot=false

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
		--root)
			asRoot=true
			;;
		-*) parseError "option" "$1" ;;
		*) parseError "argument" "$1" ;;
		esac
		shift
	done

	if [[ $asRoot == true ]]; then
		if [[ "$EUID" -ne 0 ]]; then
			die "you specified --root but forgot to execute it as root"
		fi
	elif [[ "$EUID" -eq 0 ]]; then
		die "don't run the installation as super user, use the option --root if you really want to install it for the root user"
	fi

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
main "$@"
