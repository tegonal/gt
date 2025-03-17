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
#  installs shellspec 0.28.1 into $HOME/.local/lib
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
shopt -s inherit_errexit
unset CDPATH

declare currentDir
currentDir=$(pwd)
tmpDir=$(mktemp -d -t download-shellspec-XXXXXXXXXX)
cd "$tmpDir"
echo "4cac73d958d1ca8c502f3aff1a3b3cfa46ab0062f81f1cc522b83b7b2b302175  shellspec" >shellspec.sha256

wgetExists="$(command -v wget)"
if [[ -n $wgetExists ]]; then
	wget --no-verbose https://git.io/shellspec
else
	# if wget does not exist, then we try it with curl
	curl https://git.io/shellspec -L -o "shellspec"
fi

sha256sum -c shellspec.sha256
shellspecInHomeLocalLib="$HOME/.local/lib/shellspec"
if [[ -d "$shellspecInHomeLocalLib" ]]; then
	echo "going to remove the existing installation in $shellspecInHomeLocalLib"
	chmod -R 777 "$shellspecInHomeLocalLib" || true
	rm -r "$shellspecInHomeLocalLib"
fi

sh ./shellspec 0.28.1 -y
cd "$currentDir"
echo "shellspec version is:"
shellspec --version
