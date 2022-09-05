#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.5.1
#
#######  Description  #############
#
#  internal utility functions for dealing with the pulled file
#  no backward compatibility guarantees or whatsoever
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GGET_VERSION='v0.5.0-SNAPSHOT'

if ! [[ -v dir_of_gget ]]; then
	dir_of_gget="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gget
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gget/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function pulledTsvHeader() {
	printf "tag\tfile\trelativeTarget\tsha512\n"
}
function pulledTsvEntry() {
	local tag file relativeTarget sha512
	# params is required for parseFnArgs thus:
	# shellcheck disable=SC2034
	local -ra params=(tag file relativeTarget sha512)
	parseFnArgs params "$@"
	printf "%s\t" "$tag" "$file" "$relativeTarget"
	printf "%s\n" "$sha512"
}

function exitIfHeaderOfPulledTsvIsWrong() {
	local -r pulledTsv=$1
	shift
	local currentHeader expectedHeader
	currentHeader="$(head -n 1 "$pulledTsv")" || die "could not read the current pulled.tsv at %s" "$pulledTsv"
	# we are aware of that the || disables set -e for pulledTsvHeader
	# shellcheck disable=SC2310
	expectedHeader=$(pulledTsvHeader) || die "looks like we discovered a bug, was not able to create the pulledTsvHeader"
	if [[ "$currentHeader" != "$expectedHeader" ]]; then
		logError "looks like the format of \033[0;36m%s\033[0m changed:" "$pulledTsv"
		cat -A >&2 <<<"Expected Header: $expectedHeader"
		cat -A >&2 <<<"Current  Header: $currentHeader"
		echo >&2 ""
		echo >&2 "In case you updated gget, then check the release notes for migration hints:"
		echo >&2 "https://github.com/tegonal/gget/releases/tag/$GGET_VERSION"
		exit 100
	fi
}

function setEntryVariables() {
	# yes the variables are not used here but they are (should be) in the parent scope
	# shellcheck disable=SC2034
	IFS=$'\t' read -r entryTag entryFile entryRelativePath entrySha <<<"$1" ||  die "could not setEntryVariables for entry:\n%s" "$1"
}

function grepPulledEntryByFile() {
	local -r pulledTsv=$1
	local -r file=$2
	shift 2
	grep -E "^[^\t]+	$file" "$@" "$pulledTsv"
}

function replacePulledEntry() {
	local pulledTsv file entry
	# params is required for parseFnArgs thus:
	# shellcheck disable=SC2034
	local -ra params=(pulledTsv file entry)
	parseFnArgs params "$@"
	# we are aware of that the || disables set -e for grepPulledEntryByFile but we want to be sure we die in case of general set -e
	# shellcheck disable=SC2310
	grepPulledEntryByFile "$pulledTsv" "$file" -v >"$pulledTsv.new" || die "could not find entry for file \033[0;36m%s\033[0m, thus cannot replace" "$file"
	mv "$pulledTsv.new" "$pulledTsv" || die "was not able to override %s with the new content (which does not contain the entry for file \033[0;36m%s\033[0m)" "$pulledTsv" "$file"
	echo "$entry" >>"$pulledTsv" || die "was not able to append the entry for file \033[0;36m%s\033[0m to %s" "$file" "$pulledTsv"
}

function readPulledTsv() {
	local workingDirAbsolute remote callback fileDescriptorOut fileDescriptorIn
	# params is required for parseFnArgs thus:
	# shellcheck disable=SC2034
	local -ra params=(workingDirAbsolute remote callback fileDescriptorOut fileDescriptorIn)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$callback" 3

	local pulledTsv
	source "$dir_of_gget/paths.source.sh" || die "could not source paths.source.sh"
	if ! [[ -f $pulledTsv ]]; then
		logWarning "Looks like remote \033[0;36m%s\033[0m is broken or no file has been fetched so far, there is no pulled.tsv, skipping it" "$remote"
		return 0
	fi

	# start from line 2, i.e. skip the header in pulled.tsv
	eval "tail -n +2 \"$pulledTsv\" >&$fileDescriptorOut" || die "could not tail %s" "$pulledTsv"
	while read -u "$fileDescriptorIn" -r entry; do
		local entryTag entryFile entryRelativePath
		setEntryVariables "$entry"
		local entryAbsolutePath
		#shellcheck disable=SC2310
		entryAbsolutePath=$(readlink -m "$workingDirAbsolute/$entryRelativePath") || returnDying "could not determine local absolute path of \033[0;36m%s\033[0m of remote %s" "$entryFile" "$remote" || return $?
		"$callback" "$entryTag" "$entryFile" "$entryRelativePath" "$entryAbsolutePath" || return $?
	done
}
