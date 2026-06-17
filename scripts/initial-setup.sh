#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.7.0-SNAPSHOT
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi
source "$scriptsDir/dirs.source.sh"
source "$dir_of_tegonal_scripts/utility/ask.sh"

function askToInstallShellcheckIfMissing() {
	local -r requiredShellcheckVersion=$1
	shift 1 || traceAndDie "could not shift by 1"

	if checkCommandExists shellcheck; then
		local installedShellcheckVersion
		installedShellcheckVersion="$(shellcheck --version | awk '/version:/ {print $2; exit}')"

		if [[ "$installedShellcheckVersion" == "$requiredShellcheckVersion" ]]; then
			logSuccess "shellcheck \033[0;36m%s\033[0m already installed" "$requiredShellcheckVersion"
		else
			logInfo "shellcheck version mismatch (found: \033[0;36m%s\033[0m, required: \033[0;36m%s\033[0m)" "$installedShellcheckVersion" "$requiredShellcheckVersion"
			if askYesOrNo "Shall I install shellcheck %s?" "$requiredShellcheckVersion"; then
				"$scriptsDir/../lib/tegonal-scripts/src/ci/install-shellcheck.sh"
			fi
		fi
	else
		if askYesOrNo "Shall I install shellcheck $requiredShellcheckVersion?"; then
			"$scriptsDir/../lib/tegonal-scripts/src/ci/install-shellcheck.sh"
		fi
	fi
}

function askToInstallShfmtIfMissing() {
	if checkCommandExists shfmt; then
		logSuccess "shfmt already installed"
	elif askYesOrNo "Shall I install shfmt it?"; then
		"$scriptsDir/../lib/tegonal-scripts/src/ci/install-shfmt.sh"
	fi
}

function askToInstallRustup() {
	if checkCommandExists rustup; then
		logSuccess "rustup already installed"
	elif askYesOrNo "Shall I install rustup via https://sh.rustup.rs"; then
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

		if [[ -f "$HOME/.cargo/env" ]]; then
			source "$HOME/.cargo/env"
		fi
	fi
}

function askToInstallLlvmCov() {
	if checkCommandExists cargo-llvm-cov; then
		logSuccess "cargo-llvm-cov already installed"
	elif askYesOrNo "Shall I install cargo-llvm-cov?"; then
		cargo install cargo-llvm-cov
	fi
}

function initialSetup() {

	local requiredShellcheckVersion="0.11.0"
	askToInstallShellcheckIfMissing "$requiredShellcheckVersion"
	askToInstallShfmtIfMissing
	askToInstallRustup
	askToInstallLlvmCov
}

${__SOURCED__:+return}
initialSetup "$@"
