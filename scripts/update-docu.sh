#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.2.0-SNAPSHOT
#
###################################
set -euo pipefail

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	declare -r scriptsDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$scriptsDir/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	declare -r projectDir
fi

sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/replace-help-snippet.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/update-bash-docu.sh"

function updateDocu() {
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
		gget_remote_add "src/gget-remote.sh" "add --help"
		gget_remote_remove "src/gget-remote.sh" "remove --help"
		gget_remote_list "src/gget-remote.sh" "list --help"
	)
	for ((i = 0; i < ${#additionalHelp[@]}; i += 3)); do
		replaceHelpSnippet "$projectDir/${additionalHelp[i + 1]}" "${additionalHelp[i]}-help" . README.md "${additionalHelp[i + 2]}"
	done

	logSuccess "Updating bash docu and README completed"
}

${__SOURCED__:+return}
updateDocu "$@"
