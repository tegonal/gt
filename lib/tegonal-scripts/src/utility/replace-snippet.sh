#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.14.0
#
#######  Description  #############
#
#  Helper script do replace a snippet in HTML based files (e.g. in a Markdown file).
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
#    source "$dir_of_tegonal_scripts/utility/replace-snippet.sh"
#
#    declare file
#    file=$(mktemp)
#    echo "<my-script></my-script>" > "$file"
#
#    declare dir fileName output
#    dir=$(dirname "$file")
#    fileName=$(basename "$file")
#    output=$(echo "replace with your command" | grep "command")
#
#    # replaceSnippet file id dir pattern snippet
#    replaceSnippet my-script.sh my-script-help "$dir" "$fileName" "$output"
#
#    echo "content"
#    cat "$file"
#
#    # will search for <my-script-help>...</my-script-help> in the temp file and replace it with
#    # <my-script-help>
#    #
#    # <!-- auto-generated, do not modify here but in my-snippet -->
#    # ```
#    # output of executing $(myCommand)
#    # ```
#    # </my-script-help>
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function replaceSnippet() {
	local file id dir pattern snippet
	# shellcheck disable=SC2034
	local -ra params=(file id dir pattern snippet)
	parseFnArgs params "$@"

	local quotedSnippet
	quotedSnippet=$(perl -0777 -pe 's/(@|\$|\\)/\\$1/g;' <<< "$snippet" ) || die "could not quote snippet for file \033[1;36m%s\033[0m and id %s" "$file" "$id"

	find "$dir" -name "$pattern" \
		-exec echo "updating $id in {} " \; \
		-exec perl -0777 -i \
		-pe "s@<${id}>[\S\s]+</${id}>@<${id}>\n\n<!-- auto-generated, do not modify here but in $(realpath --relative-to "$PWD" "$file") -->\n$quotedSnippet\n\n</${id}>@g;" \
		{} \; 2>/dev/null || true
}
