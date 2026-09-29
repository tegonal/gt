#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"

scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
sourceOnce "$scriptsDir/before-pr.sh"

function findScripts() {
	find "src" -name "*.sh" -not -name "*.doc.sh" "$@"
}
# make the function visible to release-files.sh / not necessary if you source release-files.sh, see further below
declare -fx findScripts

# releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and function findScripts to find the files which
# should be signed (and thus released). Assumes that a function named beforePr is in scope (which we sourced above)
"$dir_of_tegonal_scripts/releasing/release-files.sh" -v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts

# releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and function findScripts to find the files which
# should be signed (and thus released). Moreover, searches for additional occurrences where the version should be
# replaced via the specified pattern
"$dir_of_tegonal_scripts/releasing/release-files.sh" \
	-v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts \
	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"

function specialBeforePr() {
	beforePr && echo "imagine some additional work"
}
# make the function visible to release-files.sh / not necessary if you source prepare-files-next-dev-cycle.sh
# see further below
declare -fx specialBeforePr

# releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and
"$dir_of_tegonal_scripts/releasing/release-files.sh" \
	-v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts \
	--before-pr-fn specialBeforePr

# in case you want to provide your own release.sh and only want to do some pre-configuration
# then you might want to source it instead
sourceOnce "$dir_of_tegonal_scripts/releasing/release-files.sh"

# and then call the function with your pre-configuration settings:
# here we define the function which shall be used to find the files to be signed
# since "$@" follows afterwards, one could still override it via command line arguments.
# put "$@" first, if you don't want that a user can override your pre-configuration
releaseFiles --sign-fn findScripts "$@"

# call the function define --before-pr-fn, don't allow to override via command line arguments
releaseFiles "$@" --before-pr-fn specialBeforePr
