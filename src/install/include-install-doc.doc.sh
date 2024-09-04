#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit

if ! [[ -v dir_of_gt ]]; then
	# Assumes copy-install-doc.sh was fetched with gt - adjust location accordingly
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/gt/src"
fi
sourceOnce "$dir_of_gt/install/copy-install-doc.sh"

# e.g. could be used in cleanup-on-push-to-main.sh

function cleanupOnPushToMain() {
	# shellcheck disable=SC2034   # is passed by name to copyInstallDoc
	local -ar includeInstallDoc=(
	  # file_name indent
		"$projectDir/.github/workflows/gt-update.yml" '          '
  	"$projectDir/src/gitlab/install-gt.sh" ''
	)
	copyInstallDoc "$dir_of_gt/../install.doc.sh" includeInstallDoc
}
