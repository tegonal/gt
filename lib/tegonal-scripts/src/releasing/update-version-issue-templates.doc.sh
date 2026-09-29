#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"

"$dir_of_tegonal_scripts/releasing/update-issue-templates.sh" -v 0.1.0

# if you use it in combination with other tegonal-scripts files, then you might want to source it instead
sourceOnce "$dir_of_tegonal_scripts/releasing/update-issue-templates.sh"

# and then call the function
updateVersionIssueTemplate -v 0.2.0
