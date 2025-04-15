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
#  Helper script do replace a snippet in HTML based files (e.g. in a Markdown file).
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
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function replaceSnippet() {
	local file id dir pattern snippet
	# shellcheck disable=SC2034   # is passed by name to parseFnArgs
	local -ra params=(file id dir pattern snippet)
	parseFnArgs params "$@" || return $?

	SNIPPET="$snippet" find "$dir" -name "$pattern" \
		-exec echo "updating $id in {} " \; \
		-exec perl -0777 -i \
		-pe "s@<${id}>[\S\s]+</${id}>@<${id}>\n\n<!-- auto-generated, do not modify here but in $(realpath --relative-to "$PWD" "$file") -->\n\$ENV{SNIPPET}\n\n</${id}>@g;" \
		{} \; 2>/dev/null || true
}
