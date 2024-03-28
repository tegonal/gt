#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.18.0-SNAPSHOT
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

function exitBecauseNoGpgKeysImported() {
	local remote publicKeysDir gpgDir unsecurePattern
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(remote publicKeysDir gpgDir unsecurePattern)
	parseFnArgs params "$@"

	logError "no GPG keys imported, you won't be able to pull files from the remote \033[0;36m%s\033[0m without using %s true\n" "$remote" "$unsecurePattern"
	printf >&2 "Alternatively, you can:\n- place public keys in %s or\n- setup a gpg store yourself at %s\n" "$publicKeysDir" "$gpgDir"
	deleteDirChmod777 "$gpgDir"
	exit 1
}

function findAscInDir() {
	local -r dir=$1
	shift 1 || die "could not shift by 1"
	find "$dir" -maxdepth 1 -type f -name "*.asc" "$@"
}

function noAscInDir() {
	local -r dir=$1
	shift 1 || die "could not shift by 1"
	local numberOfAsc
	#shellcheck disable=SC2310			# we are aware of that set -e is disabled for findAscInDir
	numberOfAsc=$(findAscInDir "$dir" | wc -l) || die "could not determine the number of *.asc files in dir %s, see errors above (use \`gt reset\` to re-import the remote's GPG keys)" "$dir"
	((numberOfAsc == 0))
}

function checkWorkingDirExists() {
	local workingDirAbsolute=$1
	shift 1 || die "could not shift by 1"

	local workingDirPattern
	source "$dir_of_gt/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	if ! [[ -d $workingDirAbsolute ]]; then
		logError "working directory \033[0;36m%s\033[0m does not exist" "$workingDirAbsolute"
		echo >&2 "Check for typos and/or use $workingDirPattern to specify another"
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
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	if ! [[ -d $remoteDir ]]; then
		logError "remote \033[0;36m%s\033[0m does not exist, check for typos.\nFollowing the remotes which exist:" "$remote"
		sourceOnce "$dir_of_gt/gt-remote.sh"
		gt_remote_list -w "$workingDirAbsolute"
		exit 9
	fi
}

function invertBool() {
	local b=$1
	shift 1 || die "could not shift by 1"
	if [[ $b == true ]]; then
		echo "false"
	else
		echo "true"
	fi
}

function gitDiffChars() {
	local hash1 hash2
	hash1=$(git hash-object -w --stdin <<<"$1") || die "cannot calculate hash for string: %" "$1"
	hash2=$(git hash-object -w --stdin <<<"$2") || die "cannot calculate hash for string: %" "$2"
	shift 2 || die "could not shift by 2"

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
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

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
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

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
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	if ! [[ -d "$repo/.git" ]]; then
		logInfo "repo directory (or its .git directory) does not exist for remote \033[0;36m%s\033[0m. We are going to re-initialise it based on the stored gitconfig" "$remote"
		reInitialiseGitDir "$workingDirAbsolute" "$remote"
  else
  	askToDeleteAndReInitialiseGitDirIfRemoteIsBroken "$workingDirAbsolute" "$remote"
	fi
}

function initialiseGpgDir() {
	local -r gpgDir=$1
	shift 1 || die "could not shift by 1"
	mkdir "$gpgDir" || die "could not create the gpg directory at %s" "$gpgDir"
	# it's OK if we are not able to set the rights as we only use it temporary. This will cause warnings by gpg
	# so the user could be aware of that something went wrong
	chmod 700 "$gpgDir" || true
}

function latestRemoteTagIncludingChecks() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local repo
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir, maybe it does not exist anymore?"
	local -r currentDir

	local tagPattern
	source "$dir_of_gt/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	logInfo >&2 "no tag provided via argument %s, will determine latest and use it instead" "$tagPattern"
	cd "$repo" || die "could not cd to the repo to determine the latest tag: %s" "$repo"
	local tag
	tag=$(latestRemoteTag "$remote") || die "could not determine latest tag of remote \033[0;36m%s\033[0m and none set via argument %s" "$remote" "$tagPattern"
	cd "$currentDir"
	logInfo >&2 "latest is \033[0;36m%s\033[0m" "$tag"
	echo "$tag"
}

function validateGpgKeysAndImport() {
	local sourceDir gpgDir publicKeysDir validateGpgKeysAndImport_callback autoTrust
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(sourceDir gpgDir publicKeysDir validateGpgKeysAndImport_callback autoTrust)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$validateGpgKeysAndImport_callback" 4

	local autoTrustPattern
	source "$dir_of_gt/shared-patterns.source.sh" || die "could not source shared-patterns.source.sh"

	local -r sigExtension="sig"

	# shellcheck disable=SC2317   # called by name
	function validateGpgKeysAndImport_do() {
		findAscInDir "$sourceDir" -print0 >&3
		echo ""
		local publicKey
		while read -u 4 -r -d $'\0' publicKey; do

			printf "Verifying if we trust the public key %s\n" "$publicKey"

			local confirm
			confirm="--confirm=$(invertBool "$autoTrust")"

			local importIt=false

			if ! [[ -f "$publicKey.$sigExtension" ]]; then
				logWarning "There is no %s.sig next to the public key %s, cannot verify it" "$(basename "$publicKey")" "$publicKey"
			else
				# note we verify the signature of the public key based on the normal gpg dir
				# i.e. not based on the gpg dir of the remote but of the user
				# which means we trust the public key only if tbe user trusts the public key which created the sig
				if gpg --verify "$publicKey.$sigExtension" "$publicKey"; then
					confirm="false"
					importIt=true
				else
					logWarning "gpg verification failed for public key \033[0;36m%s\033[0m -- if you trust this repo, then import the public key which signed %s into your personal gpg store" "$publicKey" "$(basename "$publicKey")"
				fi
			fi

			if [[ $importIt != true ]]; then
				if [[ $autoTrust == true ]]; then
					logInfo "since you specified %s true, we trust it nonetheless. This can be a security risk" "$autoTrustPattern"
					importIt=true
				elif askYesOrNo "You can still import it via manual consent, do you want to proceed and take a look at the public key?"; then
					importIt=true
				else
					echo "Decision: do not continue! Skipping this public key accordingly"
				fi
			else
				logInfo "trust confirmed"
			fi

			if [[ $importIt == true ]] && importGpgKey "$gpgDir" "$publicKey" "--confirm=$confirm"; then
				"$validateGpgKeysAndImport_callback" "$publicKey" "$publicKey.$sigExtension"
			else
				logInfo "deleting gpg key file $publicKey for security reasons"
				rm "$publicKey" || die "was not able to delete the gpg key file \033[0;36m%s\033[0m, aborting" "$publicKey"
			fi
		done
	}
	withCustomOutputInput 3 4 validateGpgKeysAndImport_do
}

function importRemotesPulledPublicKeys() {
	local workingDirAbsolute remote importRemotesPulledPublicKeys_callback
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote importRemotesPulledPublicKeys_callback)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$importRemotesPulledPublicKeys_callback" 3

	local gpgDir publicKeysDir repo
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	# shellcheck disable=SC2317   # called by name
	function importRemotesPublicKeys_importKeyCallback() {
		local -r publicKey=$1
		local -r sig=$2
		shift 2 || die "could not shift by 2"

		mv "$publicKey" "$publicKeysDir/" || die "unable to move public key %s into public keys directory %s" "$publicKey" "$publicKeysDir"
		mv "$sig" "$publicKeysDir/" || die "unable to move the public key's signature %s into public keys directory %s" "$sig" "$publicKeysDir"
		"$importRemotesPulledPublicKeys_callback" "$publicKey" "$sig"
	}
	validateGpgKeysAndImport "$repo/.gt" "$gpgDir" "$publicKeysDir" importRemotesPublicKeys_importKeyCallback false

	deleteDirChmod777 "$repo/.gt" || logWarning "was not able to delete %s, please delete it manually" "$repo/.gt"
}

function determineDefaultBranch() {
	local -r remote=$1
	shift 1 || die "could not shift by 1"
	git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p' ||
		(
			logWarning >&2 "was not able to determine default branch for remote \033[0;36m%s\033[0m, going to use main" "$remote"
			echo "main"
		)
}

function checkoutGtDir() {
	local -r remote=$1
	local -r branch=$2
	shift 2 || die "could not shift by 2"

	git fetch --depth 1 "$remote" "$branch" || die "was not able to \033[0;36mgit fetch\033[0m from remote \033[0;36%s\033[0m" "$remote"
	git checkout "$remote/$branch" -- '.gt' && find ./.gt -maxdepth 1 -type d -not -path ./.gt -exec rm -r {} \;
}

function exitIfRepoBrokenAndReInitIfAbsent() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local remoteDir repo
	source "$dir_of_gt/paths.source.sh" || die "could not source paths.source.sh"

	if [[ -f $repo ]]; then
		die "looks like the remote \033[0;36m%s\033[0m is broken there is a file at the repo's location: %s" "$remote" "$remoteDir"
	else
		reInitialiseGitDirIfDotGitNotPresent "$workingDirAbsolute" "$remote"
	fi
}
