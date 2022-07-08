#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#
#
set -eu

declare projectDir
projectDir="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../")"
source "$projectDir/lib/tegonal-scripts/src/utility/update-bash-docu.sh"
source "$projectDir/lib/tegonal-scripts/src/utility/replace-help-snippet.sh"

find "$projectDir/src" -maxdepth 1 -name "*.sh" \
	-not -name "*.doc.sh" \
	-not -name "*utils.sh" \
	-not -name "*.source.sh" \
	-print0 |
	while read -r -d $'\0' script; do
		declare relative
		relative="$(realpath --relative-to="$projectDir" "$script")"
		declare id="${relative:4:-3}"
		updateBashDocumentation "$script" "${id////-}" . README.md
		replaceHelpSnippet "$script" "${id////-}-help" . README.md
	done

declare additionalHelp=(
	gget-remote-add "src/gget-remote.sh" "add --help"
	gget-remote-remove "src/gget-remote.sh" "remove --help"
	gget-remote-list "src/gget-remote.sh" "list --help"
)
for ((i = 0; i < ${#additionalHelp[@]}; i += 3)); do
	replaceHelpSnippet "$projectDir/${additionalHelp[i + 1]}" "${additionalHelp[i]}-help" . README.md "${additionalHelp[i + 2]}"
done
