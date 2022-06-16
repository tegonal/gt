#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#
#
#######  Description  #############
#
#  Helper script do replace a snippet in HTML based files (e.g. in a Markdown file).
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # Assuming replace-snippet.sh is in the same directory as your script
#    current_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )"
#    source "$current_dir/replace-snippet.sh"
#
#    declare file
#    file=$(mktemp)
#    echo "<my-script></my-script>" > "$file"
#
#    # replaceSnippet file id dir pattern snippet
#    replaceSnippet my-script.sh my-script-help "$(dirname "$file")" "$(basename "$file")" "$(echo "replace with your command" | grep "command")"
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
set -e

function replaceSnippet() {
  declare file id dir pattern snippet
  # args is required for parse-fn-args.sh thus:
  # shellcheck disable=SC2034
  declare args=(file id dir pattern snippet)

  declare current_dir
  current_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
  source "$current_dir/parse-fn-args.sh" || exit 1


  declare quotedSnippet
  quotedSnippet=$(echo "$snippet" | perl -0777 -pe 's/(@|\$|\\)/\\$1/g;' -pe 's/\\n/\n/g')

  find "$dir" -name "$pattern" \
    -exec echo "updating $id in {} " \; \
    -exec perl -0777 -i \
      -pe "s@<${id}>[\S\s]+</${id}>@<${id}>\n\n<!-- auto-generated, do not modify here but in $(realpath --relative-to "$PWD" "$file") -->\n$quotedSnippet\n\n</${id}>@g;" \
      {} \;  2>/dev/null || true
}
