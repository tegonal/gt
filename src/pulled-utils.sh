#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.5.0-SNAPSHOT
#######  Description  #############
#
#  internal utility functions for dealing with the pulled file
#  no backward compatibility guarantees or whatsoever
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export GT_VERSION='v1.5.0-SNAPSHOT'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function pulledTsvEntry() {
	local tag file relativeTarget tagFilter sha512
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(tag file relativeTarget tagFilter sha512)
	parseFnArgs params "$@"
	printf "%s\t" "$tag" "$file" "$relativeTarget" "$tagFilter"
	printf "%s\n" "$sha512"
}

function migratePulledTsvFormat() {
	local pulledTsvLatestVersionPragma pulledTsvLatestVersionPragmaWithoutVersion
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"
	local -r pulledTsv=$1
	local -r fromVersion=$2
	local -r toVersion=$3
	shift 3 || traceAndDie "could not shift by 2"

	function logMigrationAvailable() {
		logInfo "Format migration available, going to rewrite %s automatically from \033[0;36m%s\033[0m to version \033[0;36m%s\033[0m" "$pulledTsv" "$fromVersion" "$toVersion"
	}
	function writeVersionPragma() {
		local -r version=$1
		shift 1 || die "could not shift by 1"
		local -r pragma="${pulledTsvLatestVersionPragmaWithoutVersion}$version"
		echo "$pragma" >>"$pulledTsv.new" || die "was not able to add version pragma \`%s\` to \033[0;36m%s\033[0m -- please do it manually" "$pragma" "$pulledTsv"
	}
	function switchNewPulledTsv() {
		mv "$pulledTsv.new" "$pulledTsv" || die "was not able to override \033[0;36m%s\033[0m with the new content from %s" "$pulledTsv" "$pulledTsv.new"
	}

	local migrationFileDescriptorOut=20
	local migrationFileDescriptorIn=21

	if [[ $fromVersion == "unspecified" ]]; then
		# pulled.tsv without version pragma, convert to 1.0.0
		logMigrationAvailable
		writeVersionPragma "1.0.0"
		cat "$pulledTsv" >>"$pulledTsv.new" || die "was not able to append the current %s to \033[0;36m%s\033[0m" "$pulledTsv" "$pulledTsv.new"
		switchNewPulledTsv
		migratePulledTsvFormat "$pulledTsv" "1.0.0" "$toVersion"
	elif [[ $fromVersion == "1.0.0" ]]; then
		logMigrationAvailable
		writeVersionPragma "1.1.0"
		echo $'tag\tfile\trelativeTarget\ttagFilter\tsha512' >>"$pulledTsv.new"



		# shellcheck disable=SC2317		# is called by name
		function migrate_pulledTsv_1_0_0_to_1_1_0() {
			# start from line 3, i.e. skip the version pragma + header in pulled.tsv
			eval "tail -n +3 \"$pulledTsv\" >&$migrationFileDescriptorOut" || die "could not tail %s" "$pulledTsv"
			while read -u "$migrationFileDescriptorIn" -r entry; do
				local entryTag entryFile entryRelativePath entrySha
				IFS=$'\t' read -r entryTag entryFile entryRelativePath entrySha <<<"$entry" || die "could not set variables for entry:\n%s" "$entry"
				pulledTsvEntry "$entryTag" "$entryFile" "$entryRelativePath" ".*" "$entrySha" >>"$pulledTsv.new"
			done
		}
		withCustomOutputInput "$migrationFileDescriptorOut" "$migrationFileDescriptorIn" migrate_pulledTsv_1_0_0_to_1_1_0 "$remote"
		switchNewPulledTsv
	else
		die "no automatic migration available from \033[0;36m%s\033[0m to version \033[0;36m%s\033[0m\nIn case you updated gt, then check the release notes for migration hints:\n%s" "$fromVersion" "$toVersion" "https://github.com/tegonal/gt/releases/tag/$GT_VERSION"
	fi
}

function exitIfHeaderOfPulledTsvIsWrong() {
	local -r pulledTsv=$1
	shift 1 || traceAndDie "could not shift by 1"

	local pulledTsvLatestVersion pulledTsvLatestVersionPragma pulledTsvHeader
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local currentVersionPragma currentHeader
	currentVersionPragma="$(head -n 1 "$pulledTsv")" || die "could not read the current pulled.tsv at %s" "$pulledTsv"
	if [[ $currentVersionPragma != "$pulledTsvLatestVersionPragma" ]]; then
		local -r versionRegex="#@ Version: ([0-9]\.[0-9]\.[0-9])"
		local currentVersion
		if [[ "$currentVersionPragma" =~ $versionRegex ]]; then
			currentVersion="${BASH_REMATCH[1]}"
		else
			currentVersion="unspecified"
		fi
		logInfo "Format of \033[0;36m%s\033[0m changed\nLatest format version is: %s\nCurrent format version is: %s" "$pulledTsv" "$pulledTsvLatestVersion" "$currentVersion"
		migratePulledTsvFormat "$pulledTsv" "$currentVersion" "$pulledTsvLatestVersion"
	fi

	currentHeader="$(head -n 2 "$pulledTsv" | tail -n 1)" || die "could not read the current pulled.tsv at %s" "$pulledTsv"
	if [[ $currentHeader != "$pulledTsvHeader" ]]; then
		logError "looks like the format of \033[0;36m%s\033[0m changed:" "$pulledTsv"
		cat -A >&2 <<<"Expected Header (after Version pragma): $pulledTsvHeader"
		cat -A >&2 <<<"Current  Header (after Version pragma): $currentHeader"
		echo >&2 ""
		echo >&2 "In case you updated gt, then check the release notes for migration hints:"
		echo >&2 "https://github.com/tegonal/gt/releases/tag/$GT_VERSION"
		exit 100
	fi
}

function setEntryVariables() {
	local -ra variableNames=(entryTag entryFile entryRelativePath entryTagFilter entrySha)
	exitIfVariablesNotDeclared "${variableNames[@]}"

	# shellcheck disable=SC2034
	IFS=$'\t' read -r "${variableNames[@]}" <<<"$1" || die "could not setEntryVariables for entry:\n%s" "$1"
}

function grepPulledEntryByFile() {
	local -r pulledTsv=$1
	local -r file=$2
	shift 2 || traceAndDie "could not shift by 2"
	grep -E "^[^\t]+	$file" "$@" "$pulledTsv"
}

function replacePulledEntry() {
	local pulledTsv file entry
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(pulledTsv file entry)
	parseFnArgs params "$@"
	# shellcheck disable=SC2310 	# we are aware of that the || disables set -e for grepPulledEntryByFile but we want to be sure we die in case this file is sourced where set -e is not applied
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
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"
	if ! [[ -f $pulledTsv ]]; then
		logWarning "Looks like remote \033[0;36m%s\033[0m is broken or no file has been fetched so far, there is no pulled.tsv, skipping it" "$remote"
		return 0
	else
		exitIfHeaderOfPulledTsvIsWrong "$pulledTsv"
	fi

	# start from line 3, i.e. skip the version pragma + header in pulled.tsv
	eval "tail -n +3 \"$pulledTsv\" >&$fileDescriptorOut" || traceAndDie "could not tail %s" "$pulledTsv"
	while read -u "$fileDescriptorIn" -r entry; do
		local entryTag entryFile entryRelativePath entryTagFilter entrySha
		setEntryVariables "$entry"
		local localAbsolutePath
		#shellcheck disable=SC2310		# we know that set -e is disabled for readlink due to ||
		localAbsolutePath=$(readlink -m "$workingDirAbsolute/$entryRelativePath") || returnDying "could not determine local absolute path of \033[0;36m%s\033[0m of remote %s" "$entryFile" "$remote" || return $?
		"$readPulledTsv_callback" "$entryTag" "$entryFile" "$entryRelativePath" "$localAbsolutePath" "$entryTagFilter" "$entrySha" || return $?
	done
}
