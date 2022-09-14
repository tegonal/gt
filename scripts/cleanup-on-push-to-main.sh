#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.6.0-SNAPSHOT
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v scriptsDir ]]; then
	scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly scriptsDir
fi

if ! [[ -v projectDir ]]; then
	projectDir="$(realpath "$scriptsDir/../")"
	readonly projectDir
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$scriptsDir/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/replace-help-snippet.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/update-bash-docu.sh"

function cleanupOnPushToMain() {
	find "$projectDir/src" -maxdepth 1 -type f \
		-name "*.sh" \
		-not -name "*.doc.sh" \
		-not -name "*utils.sh" \
		-not -name "*.source.sh" \
		-print0 |
		while read -r -d $'\0' script; do
			declare relative
			relative="$(realpath --relative-to="$projectDir" "$script")"
			declare id="${relative:4:-3}"
			updateBashDocumentation "$script" "${id////-}" . README.md || return $?
			replaceHelpSnippet "$script" "${id////-}-help" . README.md || return $?
		done || die "updating bash documentation and help snippets failed, see above"

	updateBashDocumentation "$projectDir/install.sh" "install" . README.md || die "could not update install documentation"

	declare additionalHelp=(
		gget_remote_add "src/gget-remote.sh" "add --help"
		gget_remote_remove "src/gget-remote.sh" "remove --help"
		gget_remote_list "src/gget-remote.sh" "list --help"
	)
	for ((i = 0; i < ${#additionalHelp[@]}; i += 3)); do
		# we actually want word splitting for additionalHelp[i+2] thus OK
		# shellcheck disable=SC2086
		replaceHelpSnippet "$projectDir/${additionalHelp[i + 1]}" "${additionalHelp[i]}-help" . README.md ${additionalHelp[i + 2]}
	done || die "replacing help snippets failed, see above"

	local -r indent='          '
	local installScript
	installScript=$(perl -0777 -pe 's/(@|\$|\\)/\\$1/g;' < "$projectDir/install.doc.sh" | sed "s/^/$indent/" )
	perl -0777 -i -pe "s@(\n\s+# see install.doc.sh.*\n)[^#]+(# end install.doc.sh\n)@\${1}$installScript\n$indent\${2}@" \
		"$projectDir/.github/workflows/gget-update.yml"

  logSuccess "Updating bash docu and README completed"
}

${__SOURCED__:+return}
cleanupOnPushToMain "$@"
