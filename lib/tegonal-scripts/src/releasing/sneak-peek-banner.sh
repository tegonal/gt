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
#  Shows or hides the sneak peek banner
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
#    "$dir_of_tegonal_scripts/releasing/sneak-peek-banner.sh" -c hide
#
#    # if you use it in combination with other files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/sneak-peek-banner.sh"
#
#    # and then call the function
#    sneakPeekBanner -c show
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

function sneakPeekBanner() {
	local command file
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ra params=(
		command '-c|--command' "either 'show' or 'hide'"
		file '-f|--file' '(optional) the file where search & replace shall be done -- default: ./README.md'
	)
	local -r examples=$(
		# shellcheck disable=SC2312		# cat shouldn't fail for a constant string hence fine to ignore exit code
		cat <<-EOM
			# hide the sneak peek banner in ./README.md
			sneak-peek-banner.sh -c hide

			# show the sneak peek banner in ./docs/index.md
			sneak-peek-banner.sh -c show -f ./docs/index.md
		EOM
	)

	parseArguments params "$examples" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	if ! [[ -v file ]]; then file="./README.md"; fi
	exitIfNotAllArgumentsSet params "$examples" "$TEGONAL_SCRIPTS_VERSION"

	if [[ $command == show ]]; then
		echo "show sneak peek banner in $file"
		perl -0777 -i -pe 's/<!(---\n❗ You are taking[\S\s]+?---)>/$1/;' "$file"
	elif [[ $command == hide ]]; then
		echo "hide sneak peek banner in $file"
		perl -0777 -i -pe 's/((?<!<!)---\n❗ You are taking[\S\s]+?---)/<!$1>/;' "$file"
	else
		echo >&2 "only 'show' and 'hide' are supported as command. Following the output of calling --help"
		parse_args_printHelp params "$examples" "$TEGONAL_SCRIPTS_VERSION" --help
	fi
}
${__SOURCED__:+return}
sneakPeekBanner "$@"
