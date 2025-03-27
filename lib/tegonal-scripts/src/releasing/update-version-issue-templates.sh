#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.5.1
#######  Description  #############
#
#  Updates the placeholder of all labels named `Affected Version` in issue templates.
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    "$dir_of_tegonal_scripts/releasing/update-issue-templates.sh" -v 0.1.0
#
#    # if you use it in combination with other tegonal-scripts files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/update-issue-templates.sh"
#
#    # and then call the function
#    updateVersionIssueTemplate -v 0.2.0
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.5.1'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"

function updateVersionIssueTemplates() {
	source "$dir_of_tegonal_scripts/releasing/common-constants.source.sh" || traceAndDie "could not source common-constants.source.sh"

	local version directory additionalPattern
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		version "$versionParamPattern" "$versionParamDocu"
		directory '-d|--directory' '(optional) the working directory in which *.y(a)ml are searched (also in subdirectories) / you can also specify a file -- default: ./.github/ISSUE_TEMPLATE'
		additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
	)
	local -r examples=$(
		# shellcheck disable=SC2312		# cat shouldn't fail for a constant string hence fine to ignore exit code
		cat <<-EOM
			# update version to v0.1.0 for all *.y(a)ml in ./.github/ISSUE_TEMPLATE and subdirectories
			update-version-issue-templates.sh -v v0.1.0

			# update version to v0.1.0 for all *.y(a)ml in ./tpls and subdirectories
			update-version-issue-templates.sh -v v0.1.0 -d ./tpls

			# update version to v0.1.0 for all *.y(a)ml in ./.github/ISSUE_TEMPLATE and subdirectories
			# also replace occurrences of the defined pattern
			update-version-issue-templates.sh -v v0.1.0 -p "(VERSION=['\"])[^'\"]+(['\"])"
		EOM
	)

	parseArguments params "$examples" "$TEGONAL_SCRIPTS_VERSION" "$@"
	if ! [[ -v directory ]]; then directory="./.github/ISSUE_TEMPLATE"; fi
	if ! [[ -v additionalPattern ]]; then additionalPattern=""; fi
	exitIfNotAllArgumentsSet params "$examples" "$TEGONAL_SCRIPTS_VERSION"

	local where
	if [[ -f $directory ]]; then
		where="file $directory"
	else
		where="directory $directory (and subdirectories)"
	fi
	echo "set version $version in issue templates in $where"
	if [[ -n $additionalPattern ]]; then
		echo "also going to search for $additionalPattern and replace with \${1}$version\${2}"
	fi

	local script
	find "$directory" '(' -name "*.yml" -o -name "*.yaml" ')' -print0 |
		while read -r -d $'\0' script; do
			perl -0777 -i \
				-pe "s/(label:\s*Affected Version[\S\s]+placeholder:\s*)\"[^\"]+\"/\${1}\"$version\"/g;" \
				"$script" || returnDying "was not able to update the version in the issue templates" || return $?

			if [[ -n $additionalPattern ]]; then
				perl -0777 -i \
					-pe "s/$additionalPattern/\${1}$version\${2}/g;" \
					"$script" || returnDying "error during the additional replacement, see above" || return $?
			fi
		done
}
${__SOURCED__:+return}
updateVersionIssueTemplates "$@"
