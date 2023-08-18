#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.13.0-SNAPSHOT
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
export GT_VERSION='v0.13.0-SNAPSHOT'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function pulledTsvHeader() {
	printf "tag\tfile\trelativeTarget\tsha512\n"
}
function pulledTsvEntry() {
	local tag file relativeTarget sha512
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(tag file relativeTarget sha512)
	parseFnArgs params "$@"
	printf "%s\t" "$tag" "$file" "$relativeTarget"
	printf "%s\n" "$sha512"
}

function migratePulledTsvFormat() {
	local -r pulledTsv=$1
	local -r fromVersion=$2
	local -r toVersion=$3
	shift 3 || die "could not shift by 2"

	if [[ $fromVersion == "unspecified" ]]; then
		# pulled.tsv without version pragma, convert to current
		logInfo "Format migration available, going to rewrite %s automatically from \033[0;36m%s\033[0m to version \033[0;36m%s\033[0m" "$pulledTsv" "$fromVersion" "$toVersion"
		echo "$expectedVersionPragma" >>"$pulledTsv.new" || die "was not able to add version pragma \`%s\` to \033[0;36m%s\033[0m -- please do it manually" "$expectedVersionPragma" "$pulledTsv"
		cat "$pulledTsv" >>"$pulledTsv.new" || die "was not able append the current %s to \033[0;36m%s\033[0m" "$pulledTsv" "$pulledTsv.new"
		mv "$pulledTsv.new" "$pulledTsv" || die "was not able to override \033[0;36m%s\033[0m with the new content from %s" "$pulledTsv" "$pulledTsv.new"
	else
		die "no automatic migration available from \033[0;36m%s\033[0m to version \033[0;36m%s\033[0m\nIn case you updated gt, then check the release notes for migration hints:\n%s" "$fromVersion" "$toVersion" "https://github.com/tegonal/gt/releases/tag/$GT_VERSION"
	fi
}

function exitIfHeaderOfPulledTsvIsWrong() {
	local -r pulledTsv=$1
	shift 1 || die "could not shift by 1"

	local -r expectedVersion="1.0.0"
	local -r expectedVersionPragma="#@ Version: $expectedVersion"
	local currentVersionPragma currentHeader expectedHeader
	currentVersionPragma="$(head -n 1 "$pulledTsv")" || die "could not read the current pulled.tsv at %s" "$pulledTsv"
	if [[ $currentVersionPragma != "$expectedVersionPragma" ]]; then
		local -r versionRegex="#@ Version: ([0-9]\.[0-9]\.[0-9])"
		local currentVersion
		if [[ "$currentVersionPragma" =~ $versionRegex ]]; then
			currentVersion="${BASH_REMATCH[1]}"
		else
			currentVersion="unspecified"
		fi
		logInfo "Format of \033[0;36m%s\033[0m changed\nLatest format version is: %s\nCurrent format version is: %s" "$pulledTsv" "$expectedVersion" "$currentVersion"
		migratePulledTsvFormat "$pulledTsv" "$currentVersion" "$expectedVersion"
	fi

	currentHeader="$(head -n 2 "$pulledTsv" | tail -n 1)" || die "could not read the current pulled.tsv at %s" "$pulledTsv"
	# we are aware of that the || disables set -e for pulledTsvHeader
	# shellcheck disable=SC2310
	expectedHeader=$(pulledTsvHeader) || die "looks like we discovered a bug, was not able to create the pulledTsvHeader"
	if [[ $currentHeader != "$expectedHeader" ]]; then
		logError "looks like the format of \033[0;36m%s\033[0m changed:" "$pulledTsv"
		cat -A >&2 <<<"Expected Header (after Version pragma): $expectedHeader"
		cat -A >&2 <<<"Current  Header (after Version pragma): $currentHeader"
		echo >&2 ""
		echo >&2 "In case you updated gt, then check the release notes for migration hints:"
		echo >&2 "https://github.com/tegonal/gt/releases/tag/$GT_VERSION"
		exit 100
	fi
}

function setEntryVariables() {
	# yes the variables are not used here but they are (should be) in the parent scope
	# shellcheck disable=SC2034
	IFS=$'\t' read -r entryTag entryFile entryRelativePath entrySha <<<"$1" || die "could not setEntryVariables for entry:\n%s" "$1"
}

function grepPulledEntryByFile() {
	local -r pulledTsv=$1
	local -r file=$2
	shift 2 || die "could not shift by 2"
	grep -E "^[^\t]+	$file" "$@" "$pulledTsv"
}

function replacePulledEntry() {
	local pulledTsv file entry
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(pulledTsv file entry)
	parseFnArgs params "$@"
	# we are aware of that the || disables set -e for grepPulledEntryByFile but we want to be sure we die in case of general set -e
	# shellcheck disable=SC2310
	grepPulledEntryByFile "$pulledTsv" "$file" -v >"$pulledTsv.new" || die "could not find entry for file \033[0;36m%s\033[0m, thus cannot replace" "$file"
	mv "$pulledTsv.new" "$pulledTsv" || die "was not able to override %s with the new content (which does not contain the entry for file \033[0;36m%s\033[0m)" "$pulledTsv" "$file"
	echo "$entry" >>"$pulledTsv" || die "was not able to append the entry for file \033[0;36m%s\033[0m to %s" "$file" "$pulledTsv"
}

function readPulledTsv() {
	local workingDirAbsolute remote readPulledTsv_callback fileDescriptorOut fileDescriptorIn
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote readPulledTsv_callback fileDescriptorOut fileDescriptorIn)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$readPulledTsv_callback" 3

	local pulledTsv
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"
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
		"$readPulledTsv_callback" "$entryTag" "$entryFile" "$entryRelativePath" "$entryAbsolutePath" || return $?
	done
}
