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
#  installation script which builds the Rust implementation of gt from the local
#  sources (in rust/) and installs the resulting binary. Missing dependencies are
#  reported with a suggested command, they are NOT installed automatically.
#
#######  Usage  ###################
#
#    # build and install gt to $HOME/.local/lib/gt with a symlink at $HOME/.local/bin/gt
#    ./install-rust.sh
#
#    # install into a custom directory and set up a custom symbolic link
#    ./install-rust.sh --directory /opt/gt -ln /usr/local/bin/gt
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_install_rust ]]; then
	dir_of_install_rust="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_install_rust
fi

function logError() {
	local -r msg=$1
	shift 1 || die "could not shift by 1"
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
	local file
	file=$(command -v "$name") || die "%s is not installed (or not in PATH) %s" "$name" "${2:-""}"
	if ! [[ -x $file ]]; then
		die "%s is on the system at %s (according to command) but is not executable. Consider to execute:\nsudo chmod +x %s" "$name" "$file" "$file"
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

function exitIfCargoDoesNotExist() {
	if command -v cargo >/dev/null 2>&1; then
		return 0
	fi
	# cargo might be installed via rustup but the current shell has not sourced its env yet
	if [[ -f "$HOME/.cargo/env" ]]; then
		# shellcheck source=/dev/null
		source "$HOME/.cargo/env"
		if command -v cargo >/dev/null 2>&1; then
			return 0
		fi
	fi

	logError "the Rust toolchain (cargo) is not installed (or not in PATH)"
	{
		printf "Install it, then re-run this script. Suggested:\n"
		printf "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y\n"
		printf "Or use your package manager, e.g.:\n"
		printf "  apt install cargo     # Debian/Ubuntu\n"
		printf "  dnf install cargo     # Fedora\n"
		printf "  pacman -S rust        # Arch\n"
		printf "  brew install rustup   # macOS\n"
	} >&2
	exit 1
}

declare projectName="gt"
declare rustDir="$dir_of_install_rust/rust"

function install() {
	local -r installDir=$1
	local -r symbolicLink=$2
	shift 2 || die "could not shift by 2"

	[[ -f "$rustDir/Cargo.toml" ]] || die "could not find the Rust sources, expected a Cargo.toml in %s\nMake sure you run this script from within the gt repository" "$rustDir"

	logInfo "building %s from the Rust sources in %s (this can take a moment)" "$projectName" "$rustDir"
	(cd "$rustDir" && cargo build --release) || die "cargo build --release failed, see above"

	local -r binary="$rustDir/target/release/$projectName"
	[[ -f $binary ]] || die "expected the compiled binary at %s but it does not exist" "$binary"

	if [[ -d $installDir ]]; then
		logInfo "Looks like %s was already installed in %s, going to replace it" "$projectName" "$installDir"
		deleteDirChmod777 "$installDir"
		if [[ -n $symbolicLink ]]; then
			rm "$symbolicLink" >/dev/null 2>&1 || true
		fi
	fi

	local parent
	parent=$(dirname "$installDir")
	mkdir -p "$parent"
	mkdir -p "$installDir"
	cp "$binary" "$installDir/$projectName"
	chmod +x "$installDir/$projectName"
	logInfo "installed binary to %s" "$installDir/$projectName"

	if [[ -n $symbolicLink ]]; then
		logInfo "set up symbolic link %s" "$symbolicLink"
		parent=$(dirname "$symbolicLink")
		mkdir -p "$parent"
		ln -sf "$installDir/$projectName" "$symbolicLink" || sudo ln -sf "$installDir/$projectName" "$symbolicLink"
	else
		logInfo "no symbolic link set up, please do manually if required"
	fi

	# Attempt to copy zsh completions into a vendor-completions directory.
	# The completion file is in the source tree (installDir only contains the binary).
	local zshCompletion="$dir_of_install_rust/src/install/zsh/_$projectName"
	if [[ -f $zshCompletion ]]; then
		local fpath_output
		fpath_output=$(zsh -c 'echo $fpath' 2>/dev/null) || echo ""
		if [[ -n "$fpath_output" ]]; then
			local vendorPath=""
			for dir in $fpath_output; do
				if [[ $dir == *vendor-completions* ]]; then
					vendorPath="$dir"
					break
				fi
			done
			if [[ -n $vendorPath && -d $vendorPath ]]; then
				logInfo "determined zsh, trying to add completion to %s" "$vendorPath"
				if sudo -k cp "$zshCompletion" "$vendorPath"; then
					# reload compinit to activate without needing to restart the terminal
					(autoload -Uz compinit && compinit) || logInfo "autoload compinit failed, you may need to close and re-open your terminal to get gt completions"
					logSuccess "copied zsh completion into %s" "$vendorPath"
				else
					logError "was not able to copy %s into %s -- do it manually if you want" "$zshCompletion" "$vendorPath"
				fi
			fi
		fi
	fi

	logSuccess "installation completed, %s set up in %s" "$projectName" "$installDir"

	echo ""
	logInfo "Testing the installation, following the output of calling %s --help" "$projectName"
	echo ""

	local gtToTest="$installDir/$projectName"
	if [[ -n $symbolicLink ]]; then
		gtToTest="$symbolicLink"
	fi

	if "$gtToTest" --help; then
		echo ""
		logSuccess "looks like it worked"
	else
		local symlinkDir
		if [[ -n $symbolicLink ]]; then
			symlinkDir=$(dirname "$symbolicLink")
			logError "looks like something is wrong, make sure %s is in your PATH and try again. Following the PATH:\n%s" "$symlinkDir" "$PATH"
		else
			logError "looks like something is wrong, calling %s --help failed" "$gtToTest"
		fi
		exit 1
	fi

	logSuccess "thank you for using %s, please report bugs" "$projectName"
}

function exitIfValueMissing() {
	[[ -n "${2:-}" ]] || die "only %s provided but not a corresponding value" "$1"
}

function printHelp() {
	printf "Help:\n"
	printf "\t-d|--directory  (optional) the installation directory -- default: \$HOME/.local/lib/%s\n" "$projectName"
	printf "\t-ln             (optional) the path of a symbolic link which shall be set up -- default: \$HOME/.local/bin/%s if directory is not set otherwise nothing in which case no symbolic link is setup\n" "$projectName"
	printf "\t--root          (optional) if you explicitly want to run it as root\n"
	printf "\t-h|--help       prints this help\n"
}

function parseError() {
	{
		printf "unknown %s %s\n" "$1" "$2"
		printHelp
	} >&2
	exit 1
}

function main() {
	local installDir=""
	local symbolicLink=""
	local asRoot=false

	while [[ $# -gt 0 ]]; do
		case $1 in
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
		-h | --help)
			printHelp
			exit 0
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

	exitIfCommandDoesNotExist "git"
	exitIfCargoDoesNotExist

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

	install "$installDir" "$symbolicLink"
}
main "$@"
