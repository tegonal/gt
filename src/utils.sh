#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.6.0-SNAPSHOT
#######  Description  #############
#
#  internal utility functions
#  no backward compatibility guarantees or whatsoever
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/date-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/io.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function exitBecauseSigningKeyNotImported() {
	local remote publicKeysDir gpgDir unsecureParamPatternLong signingKeyAsc
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(remote publicKeysDir gpgDir unsecureParamPatternLong signingKeyAsc)
	parseFnArgs params "$@"

	logError "%s not imported, you won't be able to pull files from the remote \033[0;36m%s\033[0m without using %s true\n" "$signingKeyAsc" "$remote" "$unsecureParamPatternLong"
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

	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	if ! [[ -d $workingDirAbsolute ]]; then
		logError "working directory \033[0;36m%s\033[0m does not exist" "$workingDirAbsolute"
		echo >&2 "Check for typos and/or use $workingDirParamPattern to specify another"
		return 9
	fi
}

function exitIfWorkingDirDoesNotExist() {
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

function gitFetchTagFromRemote() {
	local remote repo tagToFetch
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(remote repo tagToFetch)
	parseFnArgs params "$@"

	local tags
	tags=$(git -C "$repo" tag) || die "The following command failed (see above): git tag"
	if grep "$tagToFetch" <<<"$tags" >/dev/null; then
		logInfo "tag \033[0;36m%s\033[0m already exists locally, skipping fetching from remote \033[0;36m%s\033[0m" "$tagToFetch" "$remote"
	else
		local remoteTags
		remoteTags=$(cd "$repo" && remoteTagsSorted "$remote" -r) || (logInfo >&2 "check your internet connection" && return 1) || return $?
		grep "$tagToFetch" <<<"$remoteTags" >/dev/null || returnDying "remote \033[0;36m%s\033[0m does not have the tag \033[0;36m%s\033[0m\nFollowing the available tags:\n%s" "$remote" "$tagToFetch" "$remoteTags" || return $?
		git -C "$repo" fetch --depth 1 "$remote" "refs/tags/$tagToFetch:refs/tags/$tagToFetch" || returnDying "was not able to fetch tag %s from remote %s" "$tagToFetch" "$remote" || return $?
	fi

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
			if askYesOrNo >&2 "Shall I delete the repo and re-initialise it based on %s" "$gitconfig"; then
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
	mkdir -p "$gpgDir" || die "could not create the gpg directory at %s" "$gpgDir"
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
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	logInfo >&2 "no tag provided via argument %s, will determine latest and use it instead" "$tagParamPattern"
	local tag
	tag=$(cd "$repo" && latestRemoteTag "$remote" "$tagFilter") ||
		die "could not determine latest tag of remote \033[0;36m%s\033[0m with filter %s, need to abort as no tag was specified via argument %s either" "$remote" "$tagFilter" "$tagParamPattern"
	logInfo >&2 "latest is \033[0;36m%s\033[0m honoring the tag filter %s" "$tag" "$tagFilter"
	echo "$tag"
}

function validateSigningKeyAndImport() {
	local remote sourceDir gpgDir publicKeysDir validateSigningKeyAndImport_callback autoTrust
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(remote sourceDir gpgDir publicKeysDir validateSigningKeyAndImport_callback autoTrust)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$validateSigningKeyAndImport_callback" 4

	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local -r publicKey="$sourceDir/$signingKeyAsc"
	local -r sigExtension="sig"
	local -r sigFile="$publicKey.$sigExtension"

	logInfo "Verifying if we trust %s\n" "$publicKey"

	local confirm
	confirm=$(invertBool "$autoTrust")

	local verified=false
	local importIt=false

	if ! [[ -f $sigFile ]]; then
		logWarning "There is no %s next to %s, cannot verify it" "$sigFile" "$publicKey"
	else
		# note we verify the signature of the public key based on the normal gpg dir
		# i.e. not based on the gpg dir of the remote but of the user
		# which means we trust the public key only if the user trusts the public key which created the sig
		if gpg --verify "$sigFile" "$publicKey"; then
			verified=true
			confirm=false
			# new line on purpose to separate output of verify
			echo ""

			# signature is valid but it could be that the gpg key was expired or even revoked by now
			local keyData keyId
			keyData=$(getSigningGpgKeyData "$sigFile") || die "could not get the key data of %s" "$sigFile"
			keyId=$(extractGpgKeyIdFromKeyData "$keyData")
			if isGpgKeyInKeyDataExpired "$keyData"; then
				local expirationTimestamp
				expirationTimestamp=$(extractExpirationTimestampFromKeyData "$keyData") || die "could not extract the expiration timestamp out of the key data:\n%" "$keyData"
				expirationDate=$(timestampToDateTime "$expirationTimestamp") || die "was not able to convert the expiration timestamp %s to a date" "$expirationTimestamp"

				if [[ $autoTrust == true ]]; then
					logInfo "The key %s used to sign %s expired at %s, ignoring it since you specified % true" "$keyId" "$publicKey" "$expirationDate" "$autoTrustParamPatternLong"
					importIt=true
				else
					logInfo "The key %s used to sign %s expired at %s" "$keyId" "$publicKey" "$expirationDate"
					if askYesOrNo "The signature as such is OK and thus we assume you still trust it. Or would you like to take a closer look at the key %s?" "$keyId"; then
						listSignaturesAndHighlightKey "$keyId"
						if askYesOrNo "Do you want to trust %s seeing now more details of the key %s which signed it" "$signingKeyAsc" "$keyId"; then
							importIt=true
						else
							importIt=false
						fi
					else
						importIt=true
					fi

					if [[ $importIt == true ]]; then
						logInfo "trust confirmed for %s -- signature verified (see further above) via expired key %s" "$publicKey" "$keyId"
					fi
				fi
			elif isGpgKeyInKeyDataRevoked "$keyData"; then
				# key was revoked, lets see if the signature was created before the revocation,
				# if so, then we ask the user if they still trust it
				local getSigCreationDate sigCreationTimestamp
				getSigCreationDate=$(getSigCreationDate "$sigFile") || die "could not get the creation date of the signature %s" "$sigFile"
				sigCreationTimestamp=$(dateToTimestamp "$getSigCreationDate") || die "was not able to convert the signature creation date %s to a timestamp" "$getSigCreationDate"

				local revData revCreatedTimestamp revCreate
				revData=$(getRevocationData "$keyId" "") || die "could ont get the revocation data for key %s" "$keyId"
				revCreatedTimestamp=$(extractCreationTimestampFromRevocationData "$revData") || die "was not able to extract the revocation creation timestamp from the revocation information:\n%" "$revData"
				revCreate=$(timestampToDateTime "$revCreatedTimestamp") || die "was not able to convert the revocation creation timestamp %s to a date" "$revCreatedTimestamp"

				if ((sigCreationTimestamp < revCreatedTimestamp)); then
					logWarning "The key %s used to sign the %s was revoked at %s.\nHowever, the signature was created before at %s. You should take a closer look at the key and the reason why it was revoked to decide if you trust the signature." "$keyId" "$publicKey" "$revCreate" "$getSigCreationDate"

					printf "Press enter to see the signatures of %s (will be shown automatically after 20 seconds)\n\n" "$keyId"
					read -t 20 -r || true

					listSignaturesAndHighlightKey "$keyId"

					if askYesOrNo "Do you want to trust the %s although the key %s signing it was revoked?" "$signingKeyAsc" "$keyId"; then
						logInfo "trust confirmed for %s -- signature verified (see further above) via revoked key %s" "$publicKey" "$keyId"
						importIt=true
					else
						importIt=false
					fi
				else
					logError "The key %s used to sign the %s was revoked at %s and but the signature was created afterwards at %s -- i.e. we cannot trust it" "$keyId" "$signingKeyAsc" "$revCreate" "$getSigCreationDate"
					importIt=false
				fi
			else
				logInfo "trust confirmed for %s -- signature verified" "$publicKey"
				importIt=true
			fi
		else
			# new line on purpose to separate output of verify
			echo ""
			logWarning "gpg verification failed for signing key \033[0;36m%s\033[0m -- if you trust this repo, then import the public key which signed %s into your personal gpg store" "$publicKey" "$signingKeyAsc"
		fi
	fi

	if [[ $verified != true ]]; then
		if [[ $autoTrust == true ]]; then
			logInfo "since you specified %s true, we trust it nonetheless. This can be a security risk" "$autoTrustParamPatternLong"
			importIt=true
		else
			logInfo "You can still trust this repository via manual consent.\nIf you do, then the %s of this remote will be stored in the remote's gpg store (not in your personal store) located at:\n%s" "$signingKeyAsc" "$gpgDir"
			if askYesOrNo "Do you want to proceed and take a look at the %s of remote %s to be able to decide if you trust it or not?" "$signingKeyAsc" "$remote"; then
				importIt=true
			else
				echo "Decision: do not continue! Skipping this public key accordingly"
			fi
		fi
	fi

	local confirmationQuestion
	if [[ $confirm == false ]]; then
		confirmationQuestion=""
	else
		confirmationQuestion="The above key(s) will be used to verify the files you will pull from remote $remote, do you trust them?"
	fi

	if [[ $importIt == true ]] && echo "" && importGpgKey "$gpgDir" "$publicKey" "$confirmationQuestion"; then
		"$validateSigningKeyAndImport_callback" "$publicKey" "$sigFile"
	else
		logInfo "deleting gpg key file $publicKey for security reasons"
		rm "$publicKey" || die "was not able to delete the gpg key file \033[0;36m%s\033[0m, aborting" "$publicKey"
	fi
}

function importRemotesPulledSigningKey() {
	source "$dir_of_gt/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local workingDirAbsolute remote importRemotesPulledSigningKey_callback
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote importRemotesPulledSigningKey_callback)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$importRemotesPulledSigningKey_callback" 3

	local gpgDir publicKeysDir repo lastSigningKeyCheckFile
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	# shellcheck disable=SC2329   # called by name
	function importRemotesPublicKeys_importKeyCallback() {
		local -r publicKey=$1
		local -r sig=$2
		shift 2 || traceAndDie "could not shift by 2"

		mv "$publicKey" "$publicKeysDir/" || die "unable to move public key \033[0;36m%s\033[0m into public keys directory %s" "$publicKey" "$publicKeysDir"
		mv "$sig" "$publicKeysDir/" || die "unable to move the public key's signature \033[0;36m%s\033[0m into public keys directory %s" "$sig" "$publicKeysDir"
		"$importRemotesPulledSigningKey_callback" "$publicKey" "$sig"
	}
	validateSigningKeyAndImport "$remote" "$repo/$defaultWorkingDir" "$gpgDir" "$publicKeysDir" importRemotesPublicKeys_importKeyCallback false
	date +"%Y-%m-%d" >"$lastSigningKeyCheckFile"
	deleteDirChmod777 "$repo/.gt" || logWarning "was not able to delete %s, please delete it manually" "$repo/.gt"
}

function determineDefaultBranch() {
	local workingDirAbsolute remote
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(workingDirAbsolute remote)
	parseFnArgs params "$@"

	local repo
	source "$dir_of_gt/paths.source.sh" || traceAndDie "could not source paths.source.sh"

	local defaultBranch
	defaultBranch=$(git --git-dir "$repo/.git" ls-remote --symref "$remote" HEAD 2>/dev/null | sed -n 's|^ref: refs/heads/\(.*\)\tHEAD$|\1|p' || echo "")
	if [[ -n $defaultBranch ]]; then
		echo "$defaultBranch"
	else
		logWarning >&2 "was not able to determine default branch for remote \033[0;36m%s\033[0m, going to use main" "$remote"
		echo "main"
	fi
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

function doIfLastCheckMoreThanDaysAgo() {
	local days lastCheckFile callback
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(days lastCheckFile callback)
	parseFnArgs params "$@"

	exitIfArgIsNotFunction "$callback" 2

	local lastCheckTimestamp aMonthAgoTimestamp
	lastCheckTimestamp=$(date -d "-$((days + 60)) day" +%s)

	if [[ -f $lastCheckFile ]]; then
		local currentLastCheckDate
		currentLastCheckDate=$(cat "$lastCheckFile")
		lastCheckTimestamp=$(dateToTimestamp "$currentLastCheckDate") || die "looks like the date \033[0;36m%s\033[0m in %s is not in format YYYY-mm-dd" "$currentLastCheckDate" "$lastCheckFile"
	fi
	aMonthAgoTimestamp=$(date -d "-$days day" +%s)
	if ((lastCheckTimestamp < aMonthAgoTimestamp)); then
		"$callback" "$lastCheckTimestamp"
	fi
}

function gt_checkForSelfUpdate() {
	local -r lastGtUpdateCheckFile="$dir_of_gt/last-update-check.txt"

	# shellcheck disable=SC2329 # gt_checkForSelfUpdate_callback is called by name
	function gt_checkForSelfUpdate_callback() {

		local -r lastCheckTimestamp=$1
		shift 1 || traceAndDie "could not shift by 1"

		lastCheckDateInUserFormat=$(timestampToDateInUserFormat "$lastCheckTimestamp")

		echo ""
		logInfo "Going to check if there is a new version of gt since the last check on %s" "$lastCheckDateInUserFormat"
		local currentGtVersion latestGtVersion
		currentGtVersion="$("$dir_of_gt/gt.sh" --version | tail -n 1)"
		latestGtVersion="$(remoteTagsSorted 'https://github.com/tegonal/gt' | tail -n 1)"
		date +"%Y-%m-%d" >"$lastGtUpdateCheckFile"
		if [[ $currentGtVersion != "$latestGtVersion" ]]; then
			if askYesOrNo "a new version of gt is available \033[0;93m%s\033[0;36m (your current version is %s), shall I update?" "$latestGtVersion" "$currentGtVersion"; then
				gt_self_update
			fi
		else
			logInfo "... gt up-to-date in version \033[0;36m%s\033[0m" "$currentGtVersion"
		fi
	}

	doIfLastCheckMoreThanDaysAgo 15 "$lastGtUpdateCheckFile" gt_checkForSelfUpdate_callback
}
