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
#  Helper script do capture the `--help` output of a script and replace a snippet in HTML based scripts (e.g. in a Markdown script).
#  Makes use of replace-snippet.sh
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
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

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/replace-snippet.sh"

function replaceHelpSnippet() {
	local script id dir pattern varargs
	# shellcheck disable=SC2034
	local -ra params=(script id dir pattern varargs)
	parseFnArgs params "$@"

	if ((${#varargs[@]} == 0)); then
		varargs=("--help")
	fi

	local snippet
	# shellcheck disable=SC2145
	echo "capturing output of calling: $script ${varargs[@]}"
	# we actually want that the array is passed as multiple arguments
	set +e
	# shellcheck disable=SC2068
	snippet=$("$script" ${varargs[@]})
	set -e

	local quotedSnippet
	# remove ansi colour codes form snippet
	quotedSnippet=$(echo "$snippet" | perl -0777 -pe "s/\033\[([01];\d{2}|0)m//g")

	replaceSnippet "$script" "$id" "$dir" "$pattern" "$(printf "\`\`\`text\n%s\n\`\`\`" "$quotedSnippet")"
}
