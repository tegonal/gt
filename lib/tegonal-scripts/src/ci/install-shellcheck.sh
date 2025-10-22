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
#  installs shellcheck v0.11.0 into $HOME/.local/lib and sets up a symlink in $HOME/.local/bin
#
#######  Usage  ###################
#
#    # run the install-shellcheck.sh in your github/gitlab workflow
#    # for instance, assuming you fetched this file via gt and remote name is tegonal-scripts
#    # then in a github workflow you would have
#
#    jobs:
#      steps:
#        - name: install shellcheck
#          run: ./lib/tegonal-scripts/src/ci/install-shellcheck.sh
#        # and most likely as well
#        - name: run shellcheck
#          run: ./scripts/run-shellcheck.sh
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
tmpDir=$(mktemp -d -t download-shellcheck-XXXXXXXXXX) || die "could not create a temp directory"
cd "$tmpDir"
shellcheckVersion="v0.11.0"
tarFile="shellcheck-$shellcheckVersion.linux.x86_64.tar.xz"
expectedSha="8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 $tarFile"
echo "$expectedSha" >"$tarFile.sha256"

url="https://github.com/koalaman/shellcheck/releases/download/$shellcheckVersion/$tarFile"
echo "going to download shellcheck $shellcheckVersion from: $url"
if command -v curl >/dev/null; then
	curl --fail -L -O "$url" || die "could not download shellcheck"
else
	# if curl does not exist, then we try it with wget
	wget --no-verbose "$url"
fi
sha256sum -c "$tarFile.sha256" || {
	actualSha="$(sha256sum "$tarFile")"
	die "checksum did not match, aborting\nexpected:\n%s\ngiven   :\n%s" "$expectedSha" "$actualSha"
}
tar -xf "./$tarFile"
chmod +x "./shellcheck-$shellcheckVersion/shellcheck" || die "could not make shellcheck executable"

shellcheckInTmp="$tmpDir/shellcheck-$shellcheckVersion"
homeLocalBin="$HOME/.local/bin"
homeLocalLib="$HOME/.local/lib"
shellcheckInHomeLocalLib="$homeLocalLib/shellcheck-$shellcheckVersion"
shellcheckBin="$homeLocalBin/shellcheck"

mkdir -p "$homeLocalBin" || die "was not able to create the bin directory %s" "$homeLocalBin"

if [[ -d "$shellcheckInHomeLocalLib" ]]; then
	echo "going to remove the existing installation in $shellcheckInHomeLocalLib"
	rm -r "$shellcheckInHomeLocalLib" || die "was not able to remove a previous installation in %s" "$shellcheckInHomeLocalLib"
else
	mkdir -p "$homeLocalLib" || die "was not able to create the installation directory %s" "$homeLocalLib"
fi
mv "$shellcheckInTmp" "$shellcheckInHomeLocalLib"
if [[ -f "$shellcheckBin" ]]; then
	rm "$shellcheckBin"
fi
ln -s "$shellcheckInHomeLocalLib/shellcheck" "$shellcheckBin"

cd "$currentDir"

shellcheckPath=$(command -v shellcheck)
if [[ $shellcheckPath != "$shellcheckBin" ]]; then
	shellcheckCurrentVersion=$(shellcheck --version)
	logError "was able to install shellcheck in %s but \`command -v shellcheck\` returns another path:\n%s\nFollowing the output of \`shellcheck --version\`:\n%s" "$shellcheckBin" "$shellcheckPath" "$shellcheckCurrentVersion"
else
	shellcheck --version
	printf "\033[0;32mSUCCESS\033[0m: installed shellcheck %s in %s\n" "$shellcheckVersion" "$homeLocalLib"
fi
