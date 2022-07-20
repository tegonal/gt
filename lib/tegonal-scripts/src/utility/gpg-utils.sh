#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.10.0
#
#######  Description  #############
#
#  utility functions for dealing with gpg
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
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

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function trustGpgKey() {
	local gpgDir keyId
	# params is required for parse-fn-args.sh thus:
	# shellcheck disable=SC2034
	local -ra params=(gpgDir keyId)
	parseFnArgs params "$@" || return $?
	echo -e "5\ny\n" | gpg --homedir "$gpgDir" --command-fd 0 --edit-key "$keyId" trust
}

function importGpgKey() {
	local gpgDir file withConfirmation
	# params is required for parse-fn-args.sh thus:
	# shellcheck disable=SC2034
	local -ra params=(gpgDir file withConfirmation)
	parseFnArgs params "$@" || exit $?

	local outputKey
	outputKey=$(gpg --homedir "$gpgDir" --keyid-format LONG --import-options show-only --import "$file")
	local isTrusting='y'
	if [[ $withConfirmation == "--confirm=true" ]]; then
		echo "$outputKey"
		if askYesNo "The above key(s) will be used to verify the files you will pull from this remote, do you trust it?"; then
			isTrusting='y'
		else
			isTrusting='n'
		fi
		echo ""
		echo "Decision: $isTrusting"
	fi

	if [[ $isTrusting == y ]]; then
		echo "importing key $file"
		gpg --homedir "$gpgDir" --import "$file"
		echo "$outputKey" | grep pub | perl -0777 -pe "s#pub\s+[^/]+/([0-9A-Z]+).*#\$1#g" |
			while read -r keyId; do
				trustGpgKey "$gpgDir" "$keyId"
			done
		return 0
	else
		return 1
	fi
}
