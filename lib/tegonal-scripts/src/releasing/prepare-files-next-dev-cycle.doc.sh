#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"

scriptsDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
sourceOnce "$scriptsDir/before-pr.sh"

# prepare dev cycle for version v0.2.0, assumes a function beforePr is in scope which we sourced above
"$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh" -v v0.2.0

function specialBeforePr() {
	beforePr && echo "imagine some additional work"
}
# make the function visible to release-files.sh / not necessary if you source prepare-files-next-dev-cycle.sh, see further below
declare -fx specialBeforePr

# prepare dev cycle for version v0.2.0 and
# searches for additional occurrences where the version should be replaced via the specified pattern in:
# - script files in ./src and ./scripts
# - ./README.md
# uses specialBeforePr instead of beforePr
"$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh" -v v0.2.0 \
	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])" \
	--before-pr-fn specialBeforePr

# in case you want to provide your own release.sh and only want to do some pre-configuration
# then you might want to source it instead
sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-files-next-dev-cycle.sh"

# and then call the function with your pre-configuration settings:
# here we define the pattern which shall be used to replace further version occurrences
# since "$@" follows afterwards, one could still override it via command line arguments.
# put "$@" first, if you don't want that a user can override your pre-configuration
prepareNextDevCycle -p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])" "$@"

# call the function define --before-pr-fn, don't allow to override via command line arguments
prepareNextDevCycle "$@" --before-pr-fn specialBeforePr
