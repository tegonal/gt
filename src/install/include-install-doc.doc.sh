#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }

if ! [[ -v dir_of_gt ]]; then
	# Assumes include-install-doc.sh was fetched with gt - adjust location accordingly
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/gt/src"
fi
sourceOnce "$dir_of_gt/install/include-install-doc.sh"

# e.g. could be used in cleanup-on-push-to-main.sh

function cleanupOnPushToMain() {
	# shellcheck disable=SC2034   # is passed by name to copyInstallDoc
	local -ar includeInstallDocInFiles=(
		# file_name indent
		".github/workflows/gt-update.yml" '          '
		"src/gitlab/install-gt.sh" ''
	)
	includeInstallDoc "$dir_of_gt/../install.doc.sh" includeInstallDocInFiles
}
