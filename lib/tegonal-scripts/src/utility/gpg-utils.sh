#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.14.1
#
#######  Description  #############
#
#  utility functions for dealing with gpg
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
#
#    # import public-key.asc into gpg store located at ~/.gpg but ask for confirmation first
#    importGpgKey ~/.gpg ./public-key.asc --confirmation=true
#
#    # import public-key.asc into gpg store located at ~/.gpg and trust automatically
#    importGpgKey ~/.gpg ./public-key.asc --confirmation=false
#
#    # import public-key.asc into gpg store located at .gget/.gpg and trust automatically
#    importGpgKey .gget/.gpg ./public-key.asc --confirmation=false
#
#    # trust key which is identified via info.com in gpg store located at ~/.gpg
#    trustGpgKey ~/.gpg info.com
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function trustGpgKey() {
	local gpgDir keyId
	# params is required for parseFnArgs thus:
	# shellcheck disable=SC2034
	local -ra params=(gpgDir keyId)
	parseFnArgs params "$@"
	echo -e "5\ny\n" | gpg --homedir "$gpgDir" --command-fd 0 --edit-key "$keyId" trust
}

function importGpgKey() {
	local gpgDir file withConfirmation
	# params is required for parseFnArgs thus:
	# shellcheck disable=SC2034
	local -ra params=(gpgDir file withConfirmation)
	parseFnArgs params "$@"

	local outputKey
	outputKey=$(
		gpg --homedir "$gpgDir" --keyid-format LONG \
			--list-options show-user-notations,show-std-notations,show-usage,show-sig-expire \
			--import-options show-only \
			--import "$file"
	) || die "not able to show the theoretical import of %s, aborting" "$file"
	local isTrusting='y'
	if [[ $withConfirmation == "--confirm=true" ]]; then
		echo "==========================================================================="
		echo "$outputKey"
		if askYesOrNo "The above key(s) will be used to verify the files you will pull from this remote, do you trust them?"; then
			isTrusting='y'
		else
			isTrusting='n'
		fi
		echo ""
		echo "Decision: $isTrusting"
	fi

	if [[ $isTrusting == y ]]; then
		echo "importing key $file"
		gpg --homedir "$gpgDir" --import "$file" || die "failed to import $file"
		local keyId
		grep pub <<< "$outputKey" | perl -0777 -pe "s#pub\s+[^/]+/([0-9A-Z]+).*#\$1#g" |
			while read -r keyId; do
				trustGpgKey "$gpgDir" "$keyId"
			done
	else
		return 1
	fi
}
