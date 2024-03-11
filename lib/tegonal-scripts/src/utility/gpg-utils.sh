#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v2.0.0
#######  Description  #############
#
#  utility functions for dealing with gpg
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
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
#    # import public-key.asc into gpg store located at .gt/.gpg and trust automatically
#    importGpgKey .gt/.gpg ./public-key.asc --confirmation=false
#
#    # trust key which is identified via info@tegonal.com in gpg store located at ~/.gpg
#    trustGpgKey ~/.gpg info@tegonal.com
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
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(gpgDir keyId)
	parseFnArgs params "$@"
	echo -e "5\ny\n" | gpg --homedir "$gpgDir" --no-tty --command-fd 0 --edit-key "$keyId" trust
}

function importGpgKey() {
	local gpgDir file withConfirmation
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(gpgDir file withConfirmation)
	parseFnArgs params "$@"

	local outputKey
	outputKey=$(
		gpg --homedir "$gpgDir" --no-tty --keyid-format LONG \
			--list-options show-user-notations,show-std-notations,show-usage,show-sig-expire \
			--import-options show-only \
			--import "$file"
	) || die "not able to show the theoretical import of %s, aborting" "$file"
	local isTrusting='y'
	if [[ $withConfirmation != "--confirm=false" ]]; then
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
		gpg --homedir "$gpgDir" --batch --no-tty --import "$file" || die "failed to import $file"
		local keyId
		grep pub <<<"$outputKey" | perl -0777 -pe "s#pub\s+[^/]+/([0-9A-Z]+).*#\$1#g" |
			while read -r keyId; do
				echo "establishing trust for key $keyId"
				trustGpgKey "$gpgDir" "$keyId"
			done
	else
		return 1
	fi
}
