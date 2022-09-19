#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.17.1
#
#######  Description  #############
#
#  Updates the version which is placed before the `Description` section in bash files (line 8 in this file).
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh" -v 0.1.0
#
#    # if you use it in combination with other tegonal-scripts files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-README.sh"
#
#    # and then call the function
#    updateVersionReadme -v 0.2.0
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v0.17.1'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function updateVersionScripts() {
	local version directory additionalPattern
	# shellcheck disable=SC2034
	local -ra params=(
		version '-v' 'the version which shall be used'
		directory '-d|--directory' '(optional) the working directory in which *.sh are searched (also in subdirectories) / you can also specify a file -- default: ./src'
		additionalPattern '-p|--pattern' '(optional) pattern which is used in a perl command (separator /) to search & replace additional occurrences. It should define two match groups and the replace operation looks as follows: '"\\\${1}\$version\\\${2}"
	)
	local -r examples=$(
		# shellcheck disable=SC2312
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

	parseArguments params "$examples" "$TEGONAL_SCRIPTS_VERSION" "$@"
	if ! [[ -v directory ]]; then directory="./src"; fi
	if ! [[ -v additionalPattern ]]; then additionalPattern=""; fi
	exitIfNotAllArgumentsSet params "$examples" "$TEGONAL_SCRIPTS_VERSION"

	local where
	if [[ -f $directory ]]; then
		where="in file $directory"
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
