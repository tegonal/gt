#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.0
#######  Description  #############
#
#  utility functions for dealing with gpg
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
#
#    # import public-key.asc into gpg store located at ~/.gpg and trust automatically
#    importGpgKey ~/.gpg ./public-key.asc
#
#    # import public-key.asc into gpg store located at ~/.gpg but ask given question first which needs to be answered with yes
#    importGpgKey ~/.gpg ./public-key.asc "do you want to import the shown key(s)?"
#
#    # import public-key.asc into gpg store located at .gt/remotes/tegonal-scripts/public-keys/gpg
#    # and trust automatically
#    importGpgKey .gt/remotes/tegonal-scripts/public-keys/gpg ./public-key.asc
#
#    # trust key which is identified via info@tegonal.com in gpg store located at ~/.gpg
#    trustGpgKey ~/.gpg info@tegonal.com
#
#    # get the gpg key data one can retrieve via --list-key --with-colons (pub or sub) for the key which signed the given file
#    getSigningGpgKeyData "file.sig"
#
#    # get the gpg key data one can retrieve via --list-key --with-colons (pub or sub) for the key which signed the given file
#    # but searches the key not in the default gpg store but in .gt/remotes/tegonal-scripts/public-keys/gpg
#    getSigningGpgKeyData "file.sig" .gt/remotes/tegonal-scripts/public-keys/gpg
#
#    # returns the creation date of the signature
#    getSigCreationDate "file.sig"
#
#    keyData="sub:-:4096:1:4B78012139378220:..."
#
#    # extract the key id from the given key data
#    extractGpgKeyIdFromKeyData "$keyData"
#    # extract the expiration timestamp from the given key data
#    extractExpirationTimestampFromKeyData "$keyData"
#
#    # returns with 0 if the given key data (the key respectively) is expired, non-zero otherwise
#    isGpgKeyInKeyDataExpired "$keyData"
#    # returns with 0 if the given key data  (the key respectively) was revoked, non-zero otherwise
#    isGpgKeyInKeyDataRevoked "$keyData"
#
#    # returns the revocation data one can retrieve via --list-sigs --with-colons (rev) for the given key
#    getRevocationData 4B78012139378220
#
#    # returns the revocation data one can retrieve via --list-sigs --with-colons (rev) for the given key
#    # but searches the revocation not in the default gpg store but in .gt/remotes/tegonal-scripts/public-keys/gpg
#    getRevocationData 4B78012139378220 .gt/remotes/tegonal-scripts/public-keys/gpg
#
#    # extract the creation timestamp from the given revocation data
#    extractCreationTimestampFromRevocationData
#
#    # list all signatures of the given key and highlights it in the output (which especially useful if the key is a subkey
#    # and there are other subkeys)
#    listSignaturesAndHighlightKey 4B78012139378220
#
#    # list all signatures of the given key and highlights it in the output (which especially useful if the key is a subkey
#    # and there are other subkeys) but searches the revocation not in the default gpg store but in
#    # .gt/remotes/tegonal-scripts/public-keys/gpg
#    listSignaturesAndHighlightKey 4B78012139378220 .gt/remotes/tegonal-scripts/public-keys/gpg
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function trustGpgKey() {
	local gpgDir keyId
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(gpgDir keyId)
	parseFnArgs params "$@" || return $?

	local fingerprint
	fingerprint="$(gpg --homedir "$gpgDir" --with-colons --fingerprint "$keyId" | grep '^fpr:' | cut -d: -f10 | head -n1)" || die "was not able to determine fingerprint for keyId %s in gpg dir %s" "$keyId" "$gpgDir"
	echo "$fingerprint:5:" | gpg --homedir "$gpgDir" --import-ownertrust
}

function importGpgKey() {
	local gpgDir file confirmationQuestion
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(gpgDir file confirmationQuestion)
	parseFnArgs params "$@" || return $?

	local outputKey
	outputKey=$(
		gpg --homedir "$gpgDir" --no-tty --keyid-format LONG \
			--list-options show-sig-expire,show-unusable-subkeys,show-unusable-uids,show-usage,show-user-notations \
			--import-options show-only \
			--import "$file"
	) || die "not able to show the theoretical import of %s, aborting" "$file"
	local isTrusting=y
	if [[ -n $confirmationQuestion ]]; then
		echo "==========================================================================="
		echo "$outputKey"
		if askYesOrNo "%s" "$confirmationQuestion"; then
			isTrusting=y
		else
			isTrusting=n
		fi
		echo ""
		echo "Decision: $isTrusting"
	fi

	if [[ $isTrusting == y ]]; then
		local maybeSymlinkedGpgDir
		maybeSymlinkedGpgDir="$(getSaveGpgHomedir "$gpgDir")"

		echo "importing key $file"
		gpg --homedir "$maybeSymlinkedGpgDir" --batch --no-tty --import "$file" || {
			cleanupMaybeSymlinkedGpgDir "$gpgDir" "$maybeSymlinkedGpgDir"
			die "failed to import $file"
		}

		local keyId
		grep pub <<<"$outputKey" | perl -0777 -pe "s#pub\s+[^/]+/([0-9A-Z]+).*#\$1#g" |
			while read -r keyId; do
				echo "establishing trust for key $keyId"
				# shellcheck disable=SC2310   # we are aware of that set -e has no effect for trustGpgKey that's why we use || return $?
				trustGpgKey "$maybeSymlinkedGpgDir" "$keyId" || return $?
			done || {
			local exitCode=$?
			cleanupMaybeSymlinkedGpgDir "$gpgDir" "$maybeSymlinkedGpgDir"
			return "$exitCode"
		}
	else
		return 1
	fi
}

function getSigningGpgKeyData() {
	if (($# == 0)) || (($# > 2)); then
		logError "You need to pass at least 1 and at max 2 arguments to getSigningGpgKeyData, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: sigFile   	the signature file'
		echo >&2 "2: gpgDir			(optional) the gpg-dir in which we shall search for the key -- default: use gpg's default"
		printStackTrace
		exit 9
	fi
	local sigFile=$1
	local gpgDir=${2:-''}

	local sigPackets keyId
	sigPackets=$(gpg --list-packets "$sigFile") || returnDying "could not list-packets for %s" "$sigFile" || return $?
	keyId=$(grep -oE "keyid .*" <<<"$sigPackets" | cut -c7-) || returnDying "could not extract keyid from signature packets:\n%s" "$sigPackets" || return $?

	gpg --homedir "$gpgDir" --list-keys \
		--list-options show-sig-expire,show-unusable-subkeys,show-unusable-uids \
		--with-colons "$keyId" | grep -E "^(pub|sub).*$keyId" || returnDying "was not able to extract the key data for %s" "$keyId" || return $?
}

function getSigCreationDate() {
	local sigFile
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(sigFile)
	parseFnArgs params "$@" || return $?
	shift 1 || traceAndDie "could not shift by 1"

	local sigPackets keyId
	sigPackets=$(gpg --list-packets "$sigFile") || returnDying "could not list-packets for %s" "$sigFile" || return $?
	grep -oE "sig created [0-9-]+" <<<"$sigPackets" | cut -c13- || returnDying "was not able to extract the signature creation timestamp out of the signature packets:\n%s" "$sigPackets" || return $?
}

function extractGpgKeyIdFromKeyData() {
	local keyData
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(keyData)
	parseFnArgs params "$@" || return $?
	cut -d ':' -f5 <<<"$keyData"
}

function extractExpirationTimestampFromKeyData() {
	local keyData
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(keyData)
	parseFnArgs params "$@" || return $?
	cut -d ':' -f7 <<<"$keyData"
}

function isGpgKeyInKeyDataExpired() {
	local keyData
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(keyData)
	parseFnArgs params "$@" || return $?

	grep -q -E '^(sub|pub):e:' <<<"$keyData"
}

function isGpgKeyInKeyDataRevoked() {
	local keyData
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(keyData)
	parseFnArgs params "$@" || return $?

	grep -q -E '^(sub|pub):r:' <<<"$keyData"
}

function getRevocationData() {
	if (($# == 0)) || (($# > 2)); then
		logError "You need to pass at least 1 and at max 2 arguments to getRevocationData, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: keyId   		the gpg keyId for which we shall print the revocation information'
		echo >&2 "2: gpgDir			(optional) the gpg-dir in which we shall search for the key -- default: use gpg's default"
		printStackTrace
		exit 9
	fi
	local keyId=$1
	local gpgDir=${2:-''}
	shift 1 || traceAndDie "could not shift by 1"

	local sigs revData
	sigs=$(gpg --homedir "$gpgDir" --list-sigs \
		--list-options show-sig-expire,show-unusable-subkeys,show-unusable-uids \
		--with-colons "$keyId") || returnDying "could not list signatures for key %s" "$keyId" || return $?
	revData=$(perl -0777 -ne 'while (/(sub|pub):r:.*?:'"$keyId"':[\S\s]+?(rev:.*)/g) { print "$2\n"; }' <<<"$sigs")
	[[ -n $revData ]] || returnDying "was not able to extract the revocation data from the signatures (maybe it was not revoked?):\n%s" "$sigs" || return $?
	echo "$revData"
}

function extractCreationTimestampFromRevocationData() {
	local revocationData
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(revocationData)
	parseFnArgs params "$@" || return $?
	cut -d ':' -f6 <<<"$revocationData"
}

function listSignaturesAndHighlightKey() {
	if (($# == 0)) || (($# > 2)); then
		logError "You need to pass at least 1 and at max 2 arguments to listSignaturesAndHighlightKey, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: keyId   		the gpg keyId for which we shall display signatures'
		echo >&2 "2: gpgDir			(optional) the gpg-dir in which we shall search for the key -- default: use gpg's default"
		printStackTrace
		exit 9
	fi
	local keyId=$1
	local gpgDir=${2:-''}
	shift 1 || traceAndDie "could not shift by 1"

	local signatures
	signatures=$(
		gpg --homedir "$gpgDir" --list-sigs \
			--keyid-format LONG \
			--list-options show-sig-expire,show-unusable-subkeys,show-unusable-uids,show-usage,show-user-notations "$keyId"
	) || returnDying "could not list signatures for key %s" "$keyId" || return $?

	# using variable substitution in combination with ANSI colours does not seem to work properly
	# hence we use sed and ignore SC2001
	# shellcheck disable=SC2001
	sed "s/$keyId/\x1b[0;31m&\x1b[0m/g" <<<"$signatures"
}

function getSaveGpgHomedir() {
	local gpgDir
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(gpgDir)
	parseFnArgs params "$@" || return $?

	if ((${#gpgDir} < 100)); then
		echo "$gpgDir"
	else
		local tmpDir
		# we use the given gpgDir should the creation of a tmp dir fail
		tmpDir=$(mktemp -d -t gpg-homedir-XXXXXXXXXX || echo "")
		if [[ -n $tmpDir ]]; then
			ln -s "$gpgDir" "$tmpDir/gpg"
			echo "$tmpDir/gpg"
		else
			echo "$gpgDir"
		fi
	fi
}

function cleanupMaybeSymlinkedGpgDir() {
	local gpgDir maybeSymlinkedGpgDir
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(gpgDir maybeSymlinkedGpgDir)
	parseFnArgs params "$@" || return $?

	if [[ $maybeSymlinkedGpgDir != "$gpgDir" ]]; then
		# if cleanup fails then well... let's hope the system cleans it up at some point
		rm -r "$maybeSymlinkedGpgDir" || true
	fi
}
