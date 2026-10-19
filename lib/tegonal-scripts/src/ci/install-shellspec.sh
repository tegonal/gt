#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.2.0
#######  Description  #############
#
#  installs shellspec v0.28.1 into $HOME/.local/lib
#
#######  Usage  ###################
#
#    # run the install-shellspec in your github/gitlab workflow
#    # for instance, assuming you fetched this file via gt and remote name is tegonal-scripts
#    # then in a github workflow you would have
#
#    jobs:
#      steps:
#        - name: install shellspec
#          run: ./lib/tegonal-scripts/src/ci/install-shellspec.sh
#        # and most likely as well
#        - name: run shellspec
#          run: shellspec
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
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

function main() {
	local currentDir tmpDir expectedSha
	currentDir=$(pwd)
	tmpDir=$(mktemp -d -t download-shellspec-XXXXXXXXXX)
	# shellcheck disable=SC2064	# we want to expand it here since the vars are local to main
	trap "cd '$currentDir'; rm -rf '$tmpDir'" EXIT
	cd "$tmpDir"
	expectedSha="4cac73d958d1ca8c502f3aff1a3b3cfa46ab0062f81f1cc522b83b7b2b302175  install.sh"
	echo "$expectedSha" >install.sh.sha256

	if command -v curl >/dev/null; then
		curl --fail -L -O https://raw.githubusercontent.com/shellspec/shellspec/master/install.sh || die "could not download install script for shellspec"
	else
		# if curl does not exist, then we try it with wget
		wget --no-verbose https://raw.githubusercontent.com/shellspec/shellspec/master/install.sh || die "could not download install script for shellspec"
	fi

	sha256sum -c install.sh.sha256 || {
		local actualSha content
		actualSha="$(sha256sum install.sh)"
		content=$(cat install.sh)
		die "checksum did not match, aborting\nexpected:\n%s\ngiven   :\n%s\ncontent was:\n%s" \
			"$expectedSha" "$actualSha" "$content"
	}

	local homeLocalLib shellspecInHomeLocalLib homeLocalBin shellspecBin shellspecVersion
	homeLocalLib="$HOME/.local/lib"
	shellspecInHomeLocalLib="$homeLocalLib/shellspec"
	homeLocalBin="$HOME/.local/bin"
	shellspecBin="$homeLocalBin/shellspec"

	if [[ -d "$shellspecInHomeLocalLib" ]]; then
		echo "going to remove the existing installation in $shellspecInHomeLocalLib"
		chmod -R 777 "$shellspecInHomeLocalLib" || true
		rm -r "$shellspecInHomeLocalLib" || die "was not able to remove a previous installation in %s" "$shellspecInHomeLocalLib"
	fi

	shellspecVersion="0.28.1"
	sh ./install.sh "$shellspecVersion" -y

	cd "$currentDir"

	local shellspecPath shellspecCurrentVersion
	shellspecPath=$(command -v shellspec)
	shellspecCurrentVersion=$(shellspec --version)
	if [[ $shellspecPath != "$shellspecBin" ]]; then
		logError "was able to install shellspec in %s but \`command -v shellspec\` returns another path:\n%s\nFollowing the output of \`shellspec --version\`:\n%s" "$shellspecBin" "$shellspecPath" "$shellspecCurrentVersion"
	else
		printf "shellspec: %s\n" "$shellspecCurrentVersion"
		printf "\033[0;32mSUCCESS\033[0m: installed shellspec %s in %s\n" "$shellspecVersion" "$homeLocalLib"
	fi
}

main "$@"
