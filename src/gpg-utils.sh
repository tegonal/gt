#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.1.0-SNAPSHOT
#
#######  Description  #############
#
#  utility functions for dealing with gpg
#
###################################

set -e

function importKey() {
	declare gpgDir file withConfirmation
	# args is required for parse-fn-args.sh thus:
	# shellcheck disable=SC2034
	declare args=(gpgDir file withConfirmation)

	declare current_dir
	current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
	source "$current_dir/../lib/tegonal-scripts/src/utility/parse-fn-args.sh" || exit 1

	declare outputKey
	outputKey=$(gpg --homedir "$gpgDir" --keyid-format LONG --import-options show-only --import "$file")
	declare isTrusting='y'
	if [ "$withConfirmation" == "--confirm=true" ]; then
		echo "$outputKey"
		printf "\n\033[0;36mThe above key(s) will be used to verify the files you will pull from this remote, do you trust it?\033[0m y/[N]:"
		while read -r isTrusting; do
			break
		done
		echo ""
		echo "Decision: $isTrusting"
	fi
	if [ "$isTrusting" == "y" ]; then
		echo "importing key $file"
		gpg --homedir "$gpgDir" --import "$file"
		echo "$outputKey" | grep pub | perl -0777 -pe "s#pub\s+[^/]+/([0-9A-Z]+).*#\$1#g" |
			while read -r keyId; do
				echo -e "5\ny\n" | gpg --homedir "$gpgDir" --command-fd 0 --edit-key "$keyId" trust
			done
		return 0
	else
		return 1
	fi
}
