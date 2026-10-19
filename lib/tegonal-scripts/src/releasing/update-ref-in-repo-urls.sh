#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.2.0
#######  Description  #############
#
#  Searches for <repo-url>/slug/<from-ref> and replaces it with <repo-url>/slug/<to-ref>
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
#
#    # replaces all urls matching https://github.com/tegonal/scripts/(blob|tree)/main/...
#    # with https://github.com/tegonal/scripts/$1/v1.5.0/... in README.md
#    "$dir_of_tegonal_scripts/releasing/update-ref-in-repo-urls.sh" \
#    	--repo-url 'https://github.com/tegonal/scripts/' \
#    	--from-ref main --to-ref v1.5.0
#
#    # if you use it in combination with other files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/update-ref-in-repo-urls.sh"
#
#    # replaces all urls matching https://gitlab.com/foo/bar/-/(blob|tree)/v1.5.0/...
#    # with https://gitlab.com/foo/bar/-/$1/develop/... in README.md
#    updateRefInRepoUrls \
#    	--repo-url 'https://gitlab.com/foo/bar/' \
#    	--from-ref v1.5.0 --to-ref develop
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v5.2.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function updateRefInRepoUrls() {
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local fromRef toRef repoUrl file
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		repoUrl "$repoUrlParamPattern" "$repoUrlParamDocu"
		fromRef '--from-ref' 'The ref to search for (e.g. main or a tag such as v1.2.0)'
		toRef '--to-ref' 'The ref which replaces --from-ref'
		file '-f|--file' '(optional) the file where search & replace shall be done -- default: ./README.md'
	)

	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	if ! [[ -v file ]]; then file="./README.md"; fi
	exitIfNotAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"
	[[ -f "$file" ]] || die "file not found (or not a regular file): %s" "$file"

	logInfo "update ref %s with ref %s in repo urls %s" "$fromRef" "$toRef" "$repoUrl"

	# gitlab has /-/ after the repos name
	REPO_URL="${repoUrl%/}" FROM_REF="$fromRef" TO_REF="$toRef" \
		perl -0777 -i -pe 's{(\Q$ENV{REPO_URL}\E(/-)?/[\w.-]+/)\Q$ENV{FROM_REF}\E(?!\.?[\w-])}{$1$ENV{TO_REF}}g' "$file"
}
${__SOURCED__:+return}
updateRefInRepoUrls "$@"
