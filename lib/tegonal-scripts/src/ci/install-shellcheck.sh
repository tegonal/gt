#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.4.1
#######  Description  #############
#
#  installs shellcheck v0.10.0 into $HOME/.local/lib
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
shopt -s inherit_errexit
unset CDPATH

declare currentDir
currentDir=$(pwd)
tmpDir=$(mktemp -d -t download-shellcheck-XXXXXXXXXX)
cd "$tmpDir"
shellcheckVersion="v0.10.0"
echo "6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87  ./shellcheck-$shellcheckVersion.linux.x86_64.tar.xz" >"shellcheck-$shellcheckVersion.linux.x86_64.tar.xz.sha256"

wgetExists="$(command -v wget)"
if [[ -n $wgetExists ]]; then
 	wget --no-verbose "https://github.com/koalaman/shellcheck/releases/download/$shellcheckVersion/shellcheck-$shellcheckVersion.linux.x86_64.tar.xz"
else
	# if wget does not exist, then we try it with curl
	curl "https://github.com/koalaman/shellcheck/releases/download/$shellcheckVersion/shellcheck-$shellcheckVersion.linux.x86_64.tar.xz" -o "shellcheck-$shellcheckVersion.linux.x86_64.tar.xz"
fi

sha256sum -c "shellcheck-$shellcheckVersion.linux.x86_64.tar.xz.sha256"
tar -xf "./shellcheck-$shellcheckVersion.linux.x86_64.tar.xz"
chmod +x "./shellcheck-$shellcheckVersion/shellcheck"
mkdir -p "$HOME/.local/bin"
shellcheckInTmp="$tmpDir/shellcheck-$shellcheckVersion"
shellcheckInHomeLocalLib="$HOME/.local/lib/shellcheck-$shellcheckVersion"
shellcheckBin="$HOME/.local/bin/shellcheck"
if [[ -d "$shellcheckInHomeLocalLib" ]]; then
	echo "going to remove the existing installation in $shellcheckInHomeLocalLib"
	rm -r "$shellcheckInHomeLocalLib"
else
	mkdir -p "$HOME/.local/lib"
fi
mv "$shellcheckInTmp" "$shellcheckInHomeLocalLib"
if [[ -f  "$shellcheckBin" ]]; then
	rm  "$shellcheckBin"
fi
ln -s "$shellcheckInHomeLocalLib/shellcheck" "$shellcheckBin"

cd "$currentDir"
shellcheck --version
