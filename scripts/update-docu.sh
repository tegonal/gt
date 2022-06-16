#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#
#
set -e

declare projectDir
projectDir="$(realpath "$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )/../")";

function replaceHelpForCommand(){
  local command=$1
  local script=$2
  local relative=$3
  local help
  help=$("$script" --help)
  perl -0777 -i \
     -pe "s@<${command}-help>[\S\s]+</${command}-help>@<${command}-help>\n\n<!-- auto-generated, do not modify here but in $relative -->\n\`\`\`text$help\n\`\`\`\n\n</${command}-help>@g;" \
     -pe "s/\033\[(1;\d{2}|0)m//g" \
     README.md
}

source "$projectDir/src/tegonal-scripts/src/utility/update-bash-docu.sh"
find "$projectDir/src" -maxdepth 1 -name "*.sh" \
  -not -name "*.doc.sh" \
  -print0 | while read -r -d $'\0' script
    do
      declare relative
      relative="$(realpath --relative-to="$projectDir" "$script")"
      declare id="${relative:4:-3}"
      updateBashDocumentation "$script" "${id////-}" . README.md
      replaceHelpForCommand "$id" "$script" "$relative"
    done
