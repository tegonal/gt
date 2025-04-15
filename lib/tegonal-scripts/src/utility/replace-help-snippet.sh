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
#  Helper script do capture the `--help` output of a script and replace a snippet in HTML based scripts (e.g. in a Markdown script).
#  Makes use of replace-snippet.sh
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
#    source "$dir_of_tegonal_scripts/utility/replace-help-snippet.sh"
#
#    declare file
#    file=$(mktemp)
#    echo "<my-script-help></my-script-help>" > "$file"
#
#    # replaceHelpSnippet script id dir pattern
#    replaceHelpSnippet my-script.sh my-script-help "$(dirname "$file")" "$(basename "$file")"
#
#    echo "content"
#    cat "$file"
#
#    # will search for <my-script-help>...</my-script-help> in the temp file and replace it with the output of calling `my-script.sh --help`
#    # <my-script-help>
#    #
#    # <!-- auto-generated, do not modify here but in my-snippet -->
#    # ```
#    # output of executing $(my-script.sh --help)
#    # ```
#    # </my-script-help>
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/replace-snippet.sh"

function replaceHelpSnippet() {
	local script id dir pattern varargs
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(script id dir pattern varargs)
	parseFnArgs params "$@" || return $?

	if ! [[ -f $script ]] && ! checkCommandExists "$script" >/dev/null; then
		logError "$script is neither a file nor a command"
		return 1
	fi

	if [[ -f $script ]] && ! [[ -x $script ]]; then
		logError "$script is not executable"
		return 1
	fi

	if ((${#varargs[@]} == 0)); then
		varargs=("--help")
	fi

	# shellcheck disable=SC2145		# we want array expansion in string
	echo "capturing output of calling: $script ${varargs[@]}"

	local snippet cleanedUpSnippet markdownSnippet
	snippet=$("$script" "${varargs[@]}") || true
	# remove ansi colour codes from snippet
	cleanedUpSnippet=$(perl -0777 -pe "s/\033\[([01];\d{2}|0)m//g" <<<"$snippet") || die "could not quote snippet for %s" "$script"
	markdownSnippet=$(printf "\`\`\`text\n%s\n\`\`\`" "$cleanedUpSnippet") || die "could not create markdownSnippet for %s" "$script"

	replaceSnippet "$script" "$id" "$dir" "$pattern" "$markdownSnippet"
}
