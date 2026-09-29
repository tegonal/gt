#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"

function prepareNextAfterVersionUpdateHook() {
	# some additional version bumps e.g. using perl
	perl -0777 -i #...
}
# make the function visible to prepare-next-dev-cycle-templates.sh / not necessary if you source it, see further below
declare -fx prepareNextAfterVersionUpdateHook

# prepare version 0.1.0 dev cycle
"$dir_of_tegonal_scripts/releasing/prepare-next-dev-cycle-templates.sh" \
	-v v0.1.0 -k "0x945FE615904E5C85" --after-version-update-hook prepareNextAfterVersionUpdateHook

# prepare version 0.1.0 dev cycle
# searches for additional occurrences where the version should be replaced via the specified pattern in:
# - script files in ./src and ./scripts
# - ./README.md
"$dir_of_tegonal_scripts/releasing/release-files.sh" \
	-v v0.1.0 -k "0x945FE615904E5C85" --after-version-update-hook prepareNextAfterVersionUpdateHook \
	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"

# in case you want to provide your own prepare-next-dev-cycle.sh and only want to do some pre-configuration
# (such as specify the after-version-hook) then you might want to source it instead
sourceOnce "$dir_of_tegonal_scripts/releasing/prepare-next-dev-cycle-templates.sh.sh"

# and then call the function with your pre-configuration settings:
# here we define the function which shall be used as after-version-update-hook after "$@", this way one cannot
# override it. put --after-version-update-hook before "$@" if you want to define only a default
prepareNextDevCycleTemplate "$@" --after-version-update-hook prepareNextAfterVersionUpdateHook
