#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v1.0.3
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
	dir_of_tegonal_scripts="$projectDir/lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$projectDir/src/install/include-install-doc.sh"

sourceOnce "$dir_of_tegonal_scripts/utility/cleanups.sh"
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
			local relative
			relative="$(realpath --relative-to="$projectDir" "$script")"
			local id="${relative:4:-3}"
			updateBashDocumentation "$script" "${id////-}" . README.md || return $?
			replaceHelpSnippet "$script" "${id////-}-help" . README.md || return $?
		done || die "updating bash documentation and help snippets failed, see above"

	updateBashDocumentation "$projectDir/install.sh" "install" . README.md || die "could not update install documentation"
	updateBashDocumentation "$projectDir/src/install/include-install-doc.sh" "include-install" . README.md || die "could not update include-install documentation"

	local -ra additionalHelp=(
		gt-remote-add "src/gt-remote.sh" "add --help"
		gt-remote-remove "src/gt-remote.sh" "remove --help"
		gt-remote-list "src/gt-remote.sh" "list --help"
	)
	for ((i = 0; i < ${#additionalHelp[@]}; i += 3)); do
		# shellcheck disable=SC2086   # we actually want word splitting for additionalHelp[i+2] thus OK
		replaceHelpSnippet "$projectDir/${additionalHelp[i + 1]}" "${additionalHelp[i]}-help" . README.md ${additionalHelp[i + 2]}
	done || die "replacing help snippets failed, see above"

	# shellcheck disable=SC2034   # is passed by name to copyInstallSh
	local -ra includeInstallSh=(
		"$projectDir/.github/workflows/gt-update.yml" '          '
		"$projectDir/src/gitlab/install-gt.sh" ''
	)
	includeInstallDoc "$projectDir/install.doc.sh" includeInstallSh || die "could not include install.doc.sh"
	echo "included install.doc.sh"

	removeUnusedSignatures "$projectDir"

	logSuccess "Cleanup on push to main completed"
}

${__SOURCED__:+return}
cleanupOnPushToMain "$@"
