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
#  Updates the version which is placed before the `Description` section in bash files (line 8 in this file).
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
#    "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh" -v 0.1.0
#
#    # if you use it in combination with other tegonal-scripts files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"
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

function updateVersionScripts() {
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local version directory additionalPattern
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" "$versionParamDocu"
		directory '-d|--directory' '(optional) the working directory in which *.sh are searched (also in subdirectories) / you can also specify a file -- default: ./src'
		additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312		# cat shouldn't fail for a constant string hence fine to ignore exit code
		cat <<-EOM
			# update version to v0.1.0 for all *.sh in ./src and subdirectories
			update-version-scripts.sh -v v0.1.0

			# update version to v0.1.0 for all *.sh in ./scripts and subdirectories
			update-version-scripts.sh -v v0.1.0 -d ./scripts

			# update version to v0.1.0 for all *.sh in ./src and subdirectories
			# also replace occurrences of the defined pattern
			update-version-scripts.sh -v v0.1.0 -p "(VERSION=['\"])[^'\"]+(['\"])"
		EOM
	)

	parseArguments params "$examples" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	if ! [[ -v directory ]]; then directory="./src"; fi
	if ! [[ -v additionalPattern ]]; then additionalPattern=""; fi
	exitIfNotAllArgumentsSet params "$examples" "$TEGONAL_SCRIPTS_VERSION"

	local where
	if [[ -f $directory ]]; then
		where="file $directory"
	else
		where="directory $directory (and subdirectories)"
	fi
	echo "set version $version in bash headers in $where"
	if [[ -n $additionalPattern ]]; then
		echo "also going to search for $additionalPattern and replace with \${1}$version\${2}"
	fi

	local script
	find "$directory" -name "*.sh" -print0 |
		while read -r -d $'\0' script; do
			perl -0777 -i \
				-pe "s/Version:.+(\n[\S\s]+?###)/Version: $version\${1}/g;" \
				"$script" || returnDying "was not able to update the version in the header of bash files" || return $?

			if [[ -n $additionalPattern ]]; then
				perl -0777 -i \
					-pe "s/$additionalPattern/\${1}$version\${2}/g;" \
					"$script" || returnDying "error during the additional replacement, see above" || return $?
			fi
		done
}
${__SOURCED__:+return}
updateVersionScripts "$@"
