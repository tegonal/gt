#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.0
#######  Description  #############
#
#  Replaces the version used in download badge(s) and in the sneak peek banner
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    "$dir_of_tegonal_scripts/releasing/update-version-README.sh" -v 0.1.0
#
#    # if you use it in combination with other tegonal-scripts files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-README.sh"
#
#    # and then call the function
#    updateVersionReadme -v 0.2.0
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.8.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function updateVersionReadme() {
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local version file additionalPattern
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" "$versionParamDocu"
		file '-f|--file' '(optional) the file where search & replace shall be done -- default: ./README.md'
		additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312		# cat shouldn't fail for a constant string hence fine to ignore exit code
		cat <<-EOM
			# update version for ./README.md
			update-version-README.sh -v v0.1.0

			# update version for ./docs/index.md
			update-version-README.sh -v v0.1.0 -f ./docs/index.md

			# update version for ./README.md
			# also replace occurrences of the defined pattern
			update-version-README.sh -v v0.1.0 -p "(VERSION=['\"])[^'\"]+(['\"])"
		EOM
	)

	parseArguments params "$examples" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	if ! [[ -v file ]]; then file="./README.md"; fi
	if ! [[ -v additionalPattern ]]; then additionalPattern=""; fi
	exitIfNotAllArgumentsSet params "$examples" "$TEGONAL_SCRIPTS_VERSION"

	echo "set version $version for Download badges and sneak peek banner in $file"

	local -r versionWithoutLeadingV="${version:1}"

	perl -0777 -i \
		-pe "s@(\[!\[Download\]\(https://img.shields.io/badge/Download-).*(-%23[0-9a-f]+\)\]\([^\)]+(?:=|/))v[^\)]+\)@\${1}$version\${2}$version\)@g;" \
		-pe "s@(\[!\[Download\]\(https://img.shields.io/badge/Download-).*(-%23[0-9a-f]+\)\]\([^\)]+(?:=|/))[0-9][^\)]+\)@\${1}$version\${2}$versionWithoutLeadingV\)@g;" \
		-pe "s@(\[README of )[^\]]+(\].*/tree/)[^/]+/@\${1}$version\${2}$version/@;" \
		"$file" || returnDying "was not able to update the version in download badges and in the sneak peek banner" || return $?

	if [[ -n $additionalPattern ]]; then
		echo "also going to search for $additionalPattern and replace with \${1}$version\${2}"
		perl -0777 -i \
			-pe "s/$additionalPattern/\${1}$version\${2}/g;" \
			"$file" || returnDying "error during the additional replacement, see above" || return $?
	fi
}
${__SOURCED__:+return}
updateVersionReadme "$@"
