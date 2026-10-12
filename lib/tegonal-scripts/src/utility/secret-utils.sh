#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v4.12.0
#
#######  Description  #############
#
#  Utility functions for secret-tool and secrets in general.
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
#
#    source "$dir_of_tegonal_scripts/utility/secret-utils.sh"
#
#    # stores the entered password into the variable `secret`
#    promptForSecret "enter your password: " secret
#
#    # retrieves a secret identified by `group` and `key` via secret-tool from the login keyring
#    # shellcheck disable=SC2034	# we know secret is not used, only a sample
#    secret="$(getSecretViaSecretTool "group" "key")"
#
#    # stores the secret identified by `group` and `key` and value `mySecret` via secret-tool into the login keyring
#    storeSecretViaSecretTool "group" "key" "label as shown in e.g. seahorse" "mySecret"
#
#    # stores the secret identified by `group` and `key` via secret-tool into the login keyring
#    # uses stdin as input (prompts for a password if there is no input)
#    storeSecretViaSecretTool "group" "key" "label as shown in e.g. seahorse"
#
#    # retrieves a secret identified by `group` and `key` via secret-tool from the login keyring and
#    # stores it in the variable password. If the secret does not exist yet, then the given prompt is used and the secret is
#    # stores accordingly
#    getSecretViaSecretToolOrPromptAndStore "group" "key" "label as shown in e.g. seahorse" "enter your password: " password
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-utils.sh"

function getSecretViaSecretToolOrPromptAndStore() {

	exitIfCommandDoesNotExist "secret-tool" "install it via 'sudo apt install libsecret-tools'"

	if (($# != 5)); then
		logError "getSecretViaSecretToolOrPromptAndStore requires exactly 5 arguments, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#"
		echo >&2 "1: group   the group in which the secret shall be stored -- referred to as attribute in secret-tool's documentation"
		echo >&2 "2: key     the secret key -- referred to as value in the secret-tool's documentation"
		echo >&2 '3: label   the description of this key (will be shown e.g. in seahorse)'
		echo >&2 '4: prompt  the text used in case the secret does not yet exist'
		echo >&2 '5: outVar  variable name where the secret shall be stored (next to the secret-tool itself)'
		exit 1
	fi
	local -r getSecretViaSecretToolOrPromptAndStore_group=$1
	local -r getSecretViaSecretToolOrPromptAndStore_key=$2
	local -r getSecretViaSecretToolOrPromptAndStore_label=$3
	local -r getSecretViaSecretToolOrPromptAndStore_prompt=$4
	local -r getSecretViaSecretToolOrPromptAndStore_outVar=$5

	exitIfVariablesNotDeclared "$getSecretViaSecretToolOrPromptAndStore_outVar"

	local getSecretViaSecretToolOrPromptAndStore_secret

	if ! getSecretViaSecretToolOrPromptAndStore_secret=$(getSecretViaSecretTool "$getSecretViaSecretToolOrPromptAndStore_group" "$getSecretViaSecretToolOrPromptAndStore_key"); then
		promptForSecret "$getSecretViaSecretToolOrPromptAndStore_prompt" getSecretViaSecretToolOrPromptAndStore_secret || return $?
		storeSecretViaSecretTool "$getSecretViaSecretToolOrPromptAndStore_group" "$getSecretViaSecretToolOrPromptAndStore_key" "$getSecretViaSecretToolOrPromptAndStore_label" "$getSecretViaSecretToolOrPromptAndStore_secret" || return $?
	fi
	assignToVariableInOuterScope "$getSecretViaSecretToolOrPromptAndStore_outVar" "$getSecretViaSecretToolOrPromptAndStore_secret" || die "could not to assign a value to variable in outer scope named %s" "$getSecretViaSecretToolOrPromptAndStore_outVar"
}

function getSecretViaSecretTool() {
	exitIfCommandDoesNotExist "secret-tool" "install it via 'sudo apt install libsecret-tools'"
	if (($# != 2)); then
		logError "getSecretViaSecretTool requires exactly 2 arguments, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#"
		echo >&2 "1: group   the group from which the secret shall be read -- referred to as attribute in secret-tool's documentation"
		echo >&2 "2: key     the secret key -- referred to as value in the secret-tool's documentation"
		exit 1
	fi
	secret-tool lookup "$1" "$2"
}

function storeSecretViaSecretTool() {
	exitIfCommandDoesNotExist "secret-tool" "install it via 'sudo apt install libsecret-tools'"
	if (($# != 3)) && (($# != 4)); then
		logError "storeSecretViaSecretTool requires either 3 or 4 arguments, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#"
		echo >&2 "1: group   the group from which the secret shall be read -- referred to as attribute in secret-tool's documentation"
		echo >&2 "2: key     the secret key -- referred to as value in the secret-tool's documentation"
		echo >&2 '3: label   the description of this key (will be shown e.g. in seahorse)'
		echo >&2 '4: secret  the secret as such (or pass it via stdin)'
		exit 1
	fi
	if (($# == 4)); then
		echo -n "$4" | secret-tool store --label="$3" "$1" "$2"
	else
		secret-tool store --label="$3" "$1" "$2"
	fi
}

function promptForSecret() {
	if (($# != 2)); then
		logError "promptForSecret requires exactly 2 arguments, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#"
		echo >&2 '1: prompt  the text used in the prompt'
		echo >&2 '2: outVar  variable name to which the secret shall be assigned'
		exit 1
	fi

	exitIfVariablesNotDeclared "$2"

	# without using it, pasting secrets sometimes reveals parts of the secret (read is too slow)
	stty -echo
	trap "stty echo; printf '\n'; return 130" INT
	trap "stty echo" EXIT

	# shellcheck disable=SC2059 # we want to be able to use newline in the $prompt, hence OK
	printf "$1"

	local promptForSecret_password=''

	while IFS= read -r -s -n 1 promptForSecret_char; do
		if [[ $promptForSecret_char == $'\0' || $promptForSecret_char == $'\n' ]]; then
			break
		fi

		if [[ $promptForSecret_char == $'\177' ]]; then
			if [[ -n $promptForSecret_password ]]; then
				promptForSecret_password="${promptForSecret_password%?}"
				printf "\b \b" # move back, overwrite with space, move back again
			fi
		else
			promptForSecret_password+="$promptForSecret_char"
			printf "*"
		fi
	done
	stty echo

	printf "\n"

	if [[ -z $promptForSecret_password ]]; then
		die "looks like you pressed ENTER too early, secret was empty"
	fi
	assignToVariableInOuterScope "$2" "$promptForSecret_password" || die "could not assign a value to variable in outer scope named %s" "$2"
}
