#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.10.0
#######  Description  #############
#
#  installs shfmt v3.12.0_linux_amd64 into $HOME/.local/bin
#
#######  Usage  ###################
#
#    # run the install-shfmt.sh in your github/gitlab workflow
#    # for instance, assuming you fetched this file via gt and remote name is tegonal-scripts
#    # then in a github workflow you would have
#
#    jobs:
#      steps:
#        - name: install shfmt
#          run: ./lib/tegonal-scripts/src/ci/install-shfmt.sh
#        # and most likely as well
#        - name: run shfmt
#          run: ./scripts/run-shfmt.sh
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

currentDir=$(pwd)
tmpDir=$(mktemp -d -t download-shfmt-XXXXXXXXXX) || die "could not create a temp directory"
cd "$tmpDir"
shfmtVersion="v3.12.0"
binFile="shfmt_${shfmtVersion}_linux_amd64"
expectedSha="d9fbb2a9c33d13f47e7618cf362a914d029d02a6df124064fff04fd688a745ea $binFile"
echo "$expectedSha" >"$binFile.sha256"

url="https://github.com/mvdan/sh/releases/download/$shfmtVersion/$binFile"
echo "going to download shfmt $shfmtVersion from: $url"
if command -v curl >/dev/null; then
	curl --fail -L -O "$url" || die "could not download shfmt"
else
	# if curl does not exist, then we try it with wget
	wget --no-verbose "$url"
fi
sha256sum -c "$binFile.sha256" || {
	actualSha="$(sha256sum "$binFile")"
	die "checksum did not match, aborting\nexpected:\n%s\ngiven   :\n%s" "$expectedSha" "$actualSha"
}
chmod +x "./$binFile" || die "could not make shfmt executable"

shfmtInTmp="$tmpDir/$binFile"
homeLocalBin="$HOME/.local/bin"
shfmtBin="$homeLocalBin/shfmt"

mkdir -p "$homeLocalBin" || die "was not able to create the bin directory %s" "$homeLocalBin"

if [[ -f "$shfmtBin" ]]; then
	echo "going to remove the existing installation in $homeLocalBin"
	rm "$shfmtBin" || die "was not able to remove a previous installation in %s" "$homeLocalBin"
fi
mv "$shfmtInTmp" "$shfmtBin"

cd "$currentDir"

shfmtPath=$(command -v shfmt)
if [[ $shfmtPath != "$shfmtBin" ]]; then
	shfmtCurrentVersion=$(shfmt --version)
	logError "was able to install shfmt in %s but \`command -v shfmt\` returns another path:\n%s\nFollowing the output of \`shfmt --version\`:\n" "$shfmtBin" "$shfmtPath" "$shfmtCurrentVersion"
else
	shfmt --version
	printf "\033[0;32mSUCCESS\033[0m: installed shfmt %s in %s\n" "$shfmtVersion" "$homeLocalBin"
fi
