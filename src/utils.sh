#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.20.0-SNAPSHOT
#######  Description  #############
#
#  internal utility functions
#  no backward compatibility guarantees or whatsoever
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function exitBecauseSigningKeyNotImported() {
	local remote publicKeysDir gpgDir unsecureParamPatternLong signingKeyAsc
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(remote publicKeysDir gpgDir unsecureParamPatternLong signingKeyAsc)
	parseFnArgs params "$@"

	logError "%s not imported, you won't be able to pull files from the remote \033[0;36m%s\033[0m without using %s true\n"  "$signingKeyAsc" "$remote" "$unsecureParamPatternLong"
	printf >&2 "Alternatively, you can:\n- place the %s manually in %s or\n- setup a gpg store yourself at %s\n" "$signingKeyAsc" "$publicKeysDir" "$gpgDir"
	deleteDirChmod777 "$gpgDir"
	exit 1
}

function findAscInDir() {
	local -r dir=$1
	shift 1 || traceAndDie "could not shift by 1"
	find "$dir" -maxdepth 1 -type f -name "*.asc" "$@"
}

function checkWorkingDirExists() {
	local workingDirAbsolute=$1
	shift 1 || traceAndDie "could not shift by 1"

	local workingDirParamPattern
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	if ! [[ -d $workingDirAbsolute ]]; then
		logError "working directory \033[0;36m%s\033[0m does not exist" "$workingDirAbsolute"
		echo >&2 "Check for typos and/or use $workingDirParamPattern to specify another"
		return 9
	fi
}

function exitIfWorkingDirDoesNotExist() {
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkWorkingDirExists
	checkWorkingDirExists "$@" || exit $?
}

function exitIfRemoteDirDoesNotExist() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local remoteDir
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	if ! [[ -d $remoteDir ]]; then
		logError "remote \033[0;36m%s\033[0m does not exist, check for typos.\nFollowing the remotes which exist:" "$remote"
		sourceOnce "$dir_of_gt/gt-remote.sh"
		gt_remote_list -w "$workingDirAbsolute"
		exit 9
	fi
}

function checkIfDirectoryNamedIsOutsideOf() {
	local directory name parentDirectory
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(directory name parentDirectory)
	parseFnArgs params "$@"

	local directoryAbsolute parentDirectoryAbsolute
	directoryAbsolute="$(realpath "$directory")"
	parentDirectoryAbsolute="$(realpath "$parentDirectory")"
	if ! [[ "$directoryAbsolute" == "$parentDirectoryAbsolute"* ]]; then
		returnDying "the given \033[0;36m%s\033[0m %s is outside of %s" "$name" "$directoryAbsolute" "$parentDirectory"
	fi
}

function exitIfDirectoryNamedIsOutsideOf() {
	# shellcheck disable=SC2310			# we are aware of that || will disable set -e for checkIfDirectoryNamedIsOutsideOf
	checkIfDirectoryNamedIsOutsideOf "$@" || exit $?
}

function invertBool() {
	local b=$1
	shift 1 || traceAndDie "could not shift by 1"
	if [[ $b == true ]]; then
		echo "false"
	else
		echo "true"
	fi
}

function gitDiffChars() {
	local hash1 hash2
	hash1=$(git hash-object -w --stdin <<<"$1") || traceAndDie "cannot calculate hash for string: %" "$1"
	hash2=$(git hash-object -w --stdin <<<"$2") || traceAndDie "cannot calculate hash for string: %" "$2"
	shift 2 || traceAndDie "could not shift by 2"

	git --no-pager diff "$hash1" "$hash2" \
		--word-diff=color --word-diff-regex . --ws-error-highlight=all |
		grep -A 1 @@ | tail -n +2
}

function initialiseGitDir() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local repo gitconfig
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	mkdir -p "$repo" || die "could not create the repo at %s" "$repo"
	git --git-dir="$repo/.git" init || die "could not git init the repo at %s" "$repo"
}

function reInitialiseGitDir() {
	initialiseGitDir "$@"
	cp "$gitconfig" "$repo/.git/config" || die "could not copy %s to %s" "$gitconfig" "$repo/.git/config"
}

function askToDeleteAndReInitialiseGitDirIfRemoteIsBroken() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local repo gitconfig
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	if ! git --git-dir="$repo/.git" remote | grep "$remote" >/dev/null; then
		logError "looks like the .git directory of remote \033[0;36m%s\033[0m is broken. There is no remote %s set up in its gitconfig. Following the remotes:" "$remote" "$remote"
		git --git-dir="$repo/.git" remote
		if [[ -f $gitconfig ]]; then
			if askYesOrNo "Shall I delete the repo and re-initialise it based on %s" "$gitconfig"; then
				deleteDirChmod777 "$repo"
				reInitialiseGitDir "$workingDirAbsolute" "$remote"
			else
				exit 1
			fi
		else
			logInfo >&2 "%s does not exist, cannot ask to re-initialise the repo, must abort" "$gitconfig"
			exit 1
		fi
	fi
}

function reInitialiseGitDirIfDotGitNotPresent() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	if ! [[ -d "$repo/.git" ]]; then
		logInfo "repo directory (or its .git directory) does not exist for remote \033[0;36m%s\033[0m. We are going to re-initialise it based on the stored gitconfig" "$remote"
		reInitialiseGitDir "$workingDirAbsolute" "$remote"
	else
		askToDeleteAndReInitialiseGitDirIfRemoteIsBroken "$workingDirAbsolute" "$remote"
	fi
}

function initialiseGpgDir() {
	local -r gpgDir=$1
	shift 1 || traceAndDie "could not shift by 1"
	mkdir "$gpgDir" || die "could not create the gpg directory at %s" "$gpgDir"
	# it's OK if we are not able to set the rights as we only use it temporary. This will cause warnings by gpg
	# so the user could be aware of that something went wrong
	chmod 700 "$gpgDir" || true
}

function latestRemoteTagIncludingChecks() {
	local workingDirAbsolute remote tagFilter
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote tagFilter)
	parseFnArgs params "$@"

	local repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	local tagParamPattern
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	logInfo >&2 "no tag provided via argument %s, will determine latest and use it instead" "$tagParamPattern"
	local tag
	tag=$(cd "$repo" && latestRemoteTag "$remote" "$tagFilter") ||
		die "could not determine latest tag of remote \033[0;36m%s\033[0m with filter %s, need to abort as no tag was specified via argument %s either" "$remote" "$tagFilter" "$tagParamPattern"
	logInfo >&2 "latest is \033[0;36m%s\033[0m honoring the tag filter %s" "$tag" "$tagFilter"
	echo "$tag"
}

function validateSigningKeyAndImport() {
	local sourceDir gpgDir publicKeysDir validateSigningKeyAndImport_callback autoTrust
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(sourceDir gpgDir publicKeysDir validateSigningKeyAndImport_callback autoTrust)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$validateSigningKeyAndImport_callback" 4

	local autoTrustParamPattern signingKeyAsc
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local -r publicKey="$sourceDir/$signingKeyAsc"
	local -r sigExtension="sig"

	logInfo "Verifying if we trust %s\n" "$publicKey"

	local confirm
	confirm="--confirm=$(invertBool "$autoTrust")"

	local importIt=false

	if ! [[ -f "$publicKey.$sigExtension" ]]; then
		logWarning "There is no %s.%s next to %s, cannot verify it" "$signingKeyAsc" "$sigExtension" "$publicKey"
	else
		# note we verify the signature of the public key based on the normal gpg dir
		# i.e. not based on the gpg dir of the remote but of the user
		# which means we trust the public key only if the user trusts the public key which created the sig
		if gpg --verify "$publicKey.$sigExtension" "$publicKey"; then
			confirm="false"
			importIt=true
		else
			logWarning "gpg verification failed for signing key \033[0;36m%s\033[0m -- if you trust this repo, then import the public key which signed %s into your personal gpg store" "$publicKey" "$signingKeyAsc"
		fi
	fi

	if [[ $importIt != true ]]; then
		if [[ $autoTrust == true ]]; then
			logInfo "since you specified %s true, we trust it nonetheless. This can be a security risk" "$autoTrustParamPattern"
			importIt=true
		else
			logInfo "You can still trust this repository via manual consent.\nIf you do, then the %s of this remote will be stored in the remote's gpg store (not in your personal store) located at:\n%s" "$signingKeyAsc" "$gpgDir"
			if askYesOrNo "Do you want to proceed and take a look at the remote's %s to be able to decide if you trust it or not?" "$signingKeyAsc"; then
				importIt=true
			else
				echo "Decision: do not continue! Skipping this public key accordingly"
			fi
		fi
	else
		logInfo "trust confirmed (verified via public key, see further above)" "$publicKey"
	fi

	if [[ $importIt == true ]] && importGpgKey "$gpgDir" "$publicKey" "--confirm=$confirm"; then
		"$validateSigningKeyAndImport_callback" "$publicKey" "$publicKey.$sigExtension"
	else
		logInfo "deleting gpg key file $publicKey for security reasons"
		rm "$publicKey" || die "was not able to delete the gpg key file \033[0;36m%s\033[0m, aborting" "$publicKey"
	fi
}

function importRemotesPulledPublicKeys() {
	local defaultWorkingDir
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local workingDirAbsolute remote importRemotesPulledPublicKeys_callback
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote importRemotesPulledPublicKeys_callback)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$importRemotesPulledPublicKeys_callback" 3

	local gpgDir publicKeysDir repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	# shellcheck disable=SC2317   # called by name
	function importRemotesPublicKeys_importKeyCallback() {
		local -r publicKey=$1
		local -r sig=$2
		shift 2 || traceAndDie "could not shift by 2"

		mv "$publicKey" "$publicKeysDir/" || die "unable to move public key \033[0;36m%s\033[0m into public keys directory %s" "$publicKey" "$publicKeysDir"
		mv "$sig" "$publicKeysDir/" || die "unable to move the public key's signature \033[0;36m%s\033[0m into public keys directory %s" "$sig" "$publicKeysDir"
		"$importRemotesPulledPublicKeys_callback" "$publicKey" "$sig"
	}
	validateSigningKeyAndImport "$repo/$defaultWorkingDir" "$gpgDir" "$publicKeysDir" importRemotesPublicKeys_importKeyCallback false

	deleteDirChmod777 "$repo/.gt" || logWarning "was not able to delete %s, please delete it manually" "$repo/.gt"
}

function determineDefaultBranch() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	git --git-dir "$repo/.git" remote show "$remote" | sed -n '/HEAD branch/s/.*: //p' ||
		(
			logWarning >&2 "was not able to determine default branch for remote \033[0;36m%s\033[0m, going to use main" "$remote"
			echo "main"
		)
}

function checkoutGtDir() {
	local workingDirAbsolute remote branch defaultWorkingDir
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote branch defaultWorkingDir)
	parseFnArgs params "$@"

	local repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	git -C "$repo" fetch --depth 1 "$remote" "$branch" || die "was not able to \033[0;36mgit fetch\033[0m from remote \033[0;36m%s\033[0m" "$remote"
	# execute as if we are inside repo as we want to checkout there, remove all folders
	git -C "$repo" checkout "$remote/$branch" -- "$defaultWorkingDir" && find "$repo/$defaultWorkingDir" -maxdepth 1 -type d -not -path "$repo/$defaultWorkingDir" -exec rm -r {} \;
}

function exitIfRepoBrokenAndReInitIfAbsent() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local remoteDir repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	if [[ -f $repo ]]; then
		die "looks like the remote \033[0;36m%s\033[0m is broken there is a file at the repo's location: %s" "$remote" "$remoteDir"
	else
		reInitialiseGitDirIfDotGitNotPresent "$workingDirAbsolute" "$remote"
	fi
}

function logWarningCouldNotWritePullArgs() {
	logWarning "was not able to write %s %s into %s\nPlease do it manually or use %s when using 'gt pull' with the remote %s" "$@"
}
