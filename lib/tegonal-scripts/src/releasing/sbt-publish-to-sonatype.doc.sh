#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"

# ask for SONATYPE_USER and SONATYPE_PW (unless already exported beforehand) and calls sbt publishSigned
"$dir_of_tegonal_scripts/releasing/sbt-publish-to-sonatype.sh"

# predefine SONATYPE_USER, asks for SONATYPE_PW (unless already exported beforehand) and calls sbt publishSigned
SONATYPE_USER="kshjwo2" "$dir_of_tegonal_scripts/releasing/sbt-publish-to-sonatype.sh"

# if you use it in combination with other files, then you might want to source it instead
sourceOnce "$dir_of_tegonal_scripts/releasing/sbt-publish-to-sonatype.sh"

# and then call the function
sbtPublishToSonatype
SONATYPE_USER="kshjwo2" sbtPublishToSonatype
