#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
# Assumes tegonal's scripts were fetched with gt - adjust location accordingly
dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"

# checks releasing v0.1.0 makes sense and the current branch is main
"$dir_of_tegonal_scripts/releasing/pre-release-checks-git.sh" -v v0.1.0

# checks releasing v0.1.0 makes sense and the current branch is hotfix-1.0
"$dir_of_tegonal_scripts/releasing/pre-release-checks-git.sh" -v v0.1.0 -b hotfix-1.0
