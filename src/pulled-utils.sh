#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.2.0-SNAPSHOT
#
#######  Description  #############
#
#  internal utility functions for dealing with the pulled file
#  no backward compatibility guarantees or whatsoever
#
###################################
set -euo pipefail
export GGET_VERSION='v0.2.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	declare -r dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gget/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function pulledTsvHeader() {
	printf "tag\tfile\trelativeTarget\tsha512\n"
}
function pulledTsvEntry(){
	local tag file relativeTarget sha512
	# params is required for parseFnArgs thus:
	# shellcheck disable=SC2034
	local -ra params=(tag file relativeTarget sha512)
  parseFnArgs params "$@"
	printf "%s\t" "$tag" "$file" "$relativeTarget"
	printf "%s\n" "$sha512"
}

function checkHeaderOfPulledTsv() {
	local -r pulledTsv=$1
	local currentHeader
	currentHeader="$(head -n 1 "$pulledTsv")"
	local expectedHeader
	expectedHeader=$(set -e && pulledTsvHeader)
	if ! [[ "$currentHeader" == "$expectedHeader" ]]; then
		logError "looks like the format of \033[0;36m%s\033[0m changed:" "$pulledTsv"
		echo "Expected Header: $expectedHeader" | cat -A >&2
		echo "Current  Header: $currentHeader" | cat -A >&2
		echo >&2 ""
		echo >&2 "In case you updated gget, then check the release notes for migration hints:"
		echo >&2 "https://github.com/tegonal/gget/releases/tag/$GGET_VERSION"
		exit 100
	fi
}

function setEntryVariables() {
	# shellcheck disable=SC2034
	IFS=$'\t' read -r entryTag entryFile entryRelativePath entrySha <<<"$1"
}

function grepPulledEntryByFile() {
	local -r pulledTsv=$1
	local -r file=$2
	shift 2
	grep -E "^[^\t]+	$file" "$@" "$pulledTsv"
}

function replacePulledEntry() {
	local -r pulledTsv=$1
	local -r file=$2
	local -r entry=$3
	shift 3
	grepPulledEntryByFile "$pulledTsv" "$file" -v >"$pulledTsv.new"
	mv "$pulledTsv.new" "$pulledTsv"
	echo "$entry" >>"$pulledTsv"
}
