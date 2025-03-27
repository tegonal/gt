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
#  Searches for <!-- for main --> ... <!-- for main end --> as well as for
#  <!-- for a specific release --> ... <!-- for a specific release end -->
#  and kind of toggles section in the sense of  if the passed command is 'main', then
# the content of <!-- for a specific release --> sections is commented and the content in <!-- for main --> is
# uncommented. Same same but different if someone passes the command 'release'
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
#    "$dir_of_tegonal_scripts/releasing/toggle-sections.sh" -c main
#
#    # if you use it in combination with other files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/toggle-sections.sh"
#
#    # and then call the function
#    toggleSections -c release
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

function toggleSections() {
	local command file
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		command '-c|--command' "either 'main' or 'release'"
		file '-f|--file' '(optional) the file where search & replace shall be done -- default: ./README.md'
	)
	local -r examples=$(
		# shellcheck disable=SC2312		# cat shouldn't fail for a constant string hence fine to ignore exit code
		cat <<-EOM
			# comment the release sections in ./README.md and uncomment the main sections
			toggle-sections.sh -c main

			# comment the main sections in ./docs/index.md and uncomment the release sections
			toggle-sections.sh -c release -f ./docs/index.md
		EOM
	)

	parseArguments params "$examples" "$TEGONAL_SCRIPTS_VERSION" "$@"
	if ! [[ -v file ]]; then file="./README.md"; fi
	exitIfNotAllArgumentsSet params "$examples" "$TEGONAL_SCRIPTS_VERSION"

	function toggleSection() {
		local file=$1
		local comment=$2
		local uncomment=$3
		perl -0777 -i \
			-pe "s/(<!-- for $comment -->\n)\n([\S\s]*?)(\n<!-- for $comment end -->\n)/\${1}<!--\n\${2}-->\${3}/g;" \
			-pe "s/(<!-- for $uncomment -->\n)<!--\n([\S\s]*?)-->(\n<!-- for $uncomment end -->)/\${1}\n\${2}\${3}/g" \
			"$file"
	}

	if [[ $command == main ]]; then
		echo "comment release sections and uncomment main sections"
		toggleSection "$file" "release" "main"
	elif [[ $command == release ]]; then
		echo "comment main sections and uncomment release sections"
		toggleSection "$file" "main" "release"
	else
		echo >&2 "only 'main' and 'release' are supported as command. Following the output of calling --help"
		parse_args_printHelp params "$examples" "$TEGONAL_SCRIPTS_VERSION" --help
	fi
}
${__SOURCED__:+return}
toggleSections "$@"
