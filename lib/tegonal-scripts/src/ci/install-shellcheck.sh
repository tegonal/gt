#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.17.0
#
#######  Description  #############
#
#  function which searches for *.sh files within defined paths (directories or a single *.sh) and
#  runs shellcheck on each file with predefined settings i.a. sets `-s bash`
#
#######  Usage  ###################
#
#    # run the install-shellcheck.sh in your github/gitlab workflow
#    # for instance, assuming you fetched this file via gget and remote name is tegonal-scripts
#    # then in a github workflow you would have
#
#    jobs:
#      steps:
#        - name: install shellcheck v0.8.0
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
echo "ab6ee1b178f014d1b86d1e24da20d1139656c8b0ed34d2867fbb834dad02bf0a  shellcheck-v0.8.0.linux.x86_64.tar.xz" >shellcheck-v0.8.0.linux.x86_64.tar.xz.sha256
wget --no-verbose https://github.com/koalaman/shellcheck/releases/download/v0.8.0/shellcheck-v0.8.0.linux.x86_64.tar.xz
sha256sum -c shellcheck-v0.8.0.linux.x86_64.tar.xz.sha256
tar -xf ./shellcheck-v0.8.0.linux.x86_64.tar.xz
chmod +x ./shellcheck-v0.8.0/shellcheck
mkdir -p "$HOME/.local/bin"
ln -s "$tmpDir/shellcheck-v0.8.0/shellcheck" "$HOME/.local/bin/shellcheck"
cd "$currentDir"
shellcheck --version
