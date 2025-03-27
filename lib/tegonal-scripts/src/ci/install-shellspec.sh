#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.5.1
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
shopt -s inherit_errexit
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

declare currentDir
currentDir=$(pwd)
tmpDir=$(mktemp -d -t download-shellspec-XXXXXXXXXX)
cd "$tmpDir"
expectedSha="4cac73d958d1ca8c502f3aff1a3b3cfa46ab0062f81f1cc522b83b7b2b302175  shellspec"
echo "$expectedSha" >shellspec.sha256

if command -v curl >/dev/null; then
	curl  -L -O https://git.io/shellspec
else
	# if curl does not exist, then we try it with wget
		wget --no-verbose https://git.io/shellspec
fi

sha256sum -c shellspec.sha256 || {
	actualSha="$(sha256sum shellspec.sha256)"
	die "checksum did not match, aborting\nexpected:\n%s\ngiven   :\n%s" "$expectedSha" "$actualSha"
}
shellspecInHomeLocalLib="$HOME/.local/lib/shellspec"
if [[ -d "$shellspecInHomeLocalLib" ]]; then
	echo "going to remove the existing installation in $shellspecInHomeLocalLib"
	chmod -R 777 "$shellspecInHomeLocalLib" || true
	rm -r "$shellspecInHomeLocalLib" || die "was not able to remove a previous installation in %s" "$shellspecInHomeLocalLib"
fi

sh ./shellspec 0.28.1 -y
cd "$currentDir"
echo "shellspec version is:"
shellspec --version
