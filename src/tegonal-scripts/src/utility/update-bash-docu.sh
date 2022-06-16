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
#  checks if there is a script.help.sh next to the script.sh file, calls
#  replaceSnippet (from replace-snippet.sh) with its content
#  and updates the `Usage` section in script.sh accordingly
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -e
#    declare current_dir
#    current_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
#
#    # Assuming /update-bash-docu.sh is in the same directory as your script
#    source "$current_dir/update-bash-docu.sh"
#    find . -name "*.sh" \
#      -not -name "*.doc.sh" \
#      -not -path "**.history/*" \
#      -not -name "update-docu.sh" \
#      -print0 | while read -r -d $'\0' script
#        do
#          declare script="${script:2}"
#          replaceSnippetForScript "$current_dir/$script" "${script////-}" . README.md
#        done
#
###################################

set -e

function updateBashDocumentation(){
  declare script id dir pattern
  # args is required for parse-fn-args.sh thus:
  # shellcheck disable=SC2034
  declare args=(script id dir pattern)

  declare current_dir
  current_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
  source "$current_dir/parse-fn-args.sh" || exit 1
  source "$current_dir/replace-snippet.sh"

  declare snippet
  snippet=$(cat "${script::-3}.doc.sh")

  declare quotedSnippet
  quotedSnippet=$(echo "$snippet" | perl -0777 -pe 's/(\/|\$|\\)/\\$1/g;' | sed 's/^/#    /' | sed 's/^#    $/#/')

  perl -0777 -i \
    -pe "s/(###+\s+Usage\s+###+\n#\n)[\S\s]+?(\n#\n###+)/\$1${quotedSnippet}\$2/g;" \
    "$script"

  replaceSnippet "$script" "$id" "$dir" "$pattern" "\`\`\`bash\n$snippet\n\`\`\`"
}
