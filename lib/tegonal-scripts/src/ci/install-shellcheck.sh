#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v3.0.0
#######  Description  #############
#
#  function which searches for *.sh files within defined paths (directories or a single *.sh) and
#  runs shellcheck on each file with predefined settings i.a. sets `-s bash`
#
#######  Usage  ###################
#
#    # run the install-shellcheck.sh in your github/gitlab workflow
#    # for instance, assuming you fetched this file via gt and remote name is tegonal-scripts
#    # then in a github workflow you would have
#
#    jobs:
#      steps:
#        - name: install shellcheck v0.9.0
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
echo "700324c6dd0ebea0117591c6cc9d7350d9c7c5c287acbad7630fa17b1d4d9e2f  ./shellcheck-v0.9.0.linux.x86_64.tar.xz" >shellcheck-v0.9.0.linux.x86_64.tar.xz.sha256
wget --no-verbose https://github.com/koalaman/shellcheck/releases/download/v0.9.0/shellcheck-v0.9.0.linux.x86_64.tar.xz
sha256sum -c shellcheck-v0.9.0.linux.x86_64.tar.xz.sha256
tar -xf ./shellcheck-v0.9.0.linux.x86_64.tar.xz
chmod +x ./shellcheck-v0.9.0/shellcheck
mkdir -p "$HOME/.local/bin"
ln -s "$tmpDir/shellcheck-v0.9.0/shellcheck" "$HOME/.local/bin/shellcheck"
cd "$currentDir"
shellcheck --version
