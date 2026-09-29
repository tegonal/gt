#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"

function releaseScalaLib() {
	sbt publishSigned
	# or
	sbt test publishedSigned
}
# make the function visible to release-templates.sh / not necessary if you source release-templates.sh, see further below
declare -fx releaseScalaLib

# releases version v0.1.0 using releaseScalaLib as hook
"$dir_of_tegonal_scripts/releasing/release-template.sh" \
	-v v0.1.0 -k "0x945FE615904E5C85" --release-hook releaseScalaLib

# releases version v0.1.0 using releaseScalaLib as hook and
# searches for additional occurrences where the version should be replaced via the specified pattern in:
# - script files in ./src and ./scripts
# - ./README.md
"$dir_of_tegonal_scripts/releasing/release-template.sh" \
	-v v0.1.0 -k "0x945FE615904E5C85" --release-hook releaseScalaLib \
	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"

# in case you want to provide your own release.sh and only want to do some pre-configuration
# (such as specify the release-hook) then you might want to source it instead
sourceOnce "$dir_of_tegonal_scripts/releasing/release-template.sh"

# and then call the function with your pre-configuration settings:
# here we define the function which shall be used as release-hook after "$@", this way one cannot override it.
# put --release-hook before "$@" if you want to define only a default
releaseTemplates "$@" --release-hook releaseScalaLib

function releaseScalaLib_afterVersionUpdateHook() {
	# some additional version bumps (assuming version is in scope)
	local version
	perl -0777 -i -pe "s/.../$version/g" "build.sbt"
}

# and then call the function with your pre-configuration settings:
# here we define the function which shall be used as release-hook after "$@" this way one cannot override it.
# put --release-hook before "$@" if you want to define only a default
releaseTemplate "$@" --release-hook releaseScalaLib \
	--after-version-update-hook releaseScalaLib_afterVersionUpdateHook
