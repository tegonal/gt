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
#  Intended to parse command line arguments of a script which uses commands and delegates accordingly.
#  Provides a simple way to parse commands including a documentation
#  if one uses the parameter `--help` and shows the version if one uses --version.
#  I.e. that also means that `--help` and `--version` are reserved command names and should not be used by your
#  script/function as command names.
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    MY_LIB_VERSION="v1.1.0"
#
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/parse-commands.sh"
#
#    # command definitions where each command definition consists of two values (separated via space)
#    # COMMAND_NAME HELP_TEXT
#    # where the HELP_TEXT is optional in the sense of that you can use an empty string
#    # shellcheck disable=SC2034   # is passed by name to parseCommands
#    declare commands=(
#    	add 'command to add people to your list'
#    	config 'manage configuration'
#    	login ''
#    )
#
#    # the function which is responsible to load the corresponding file which contains the function of this particular command
#    function sourceCommand() {
#    	local -r command=$1
#    	shift
#    	sourceOnce "my-lib-$command.sh"
#    }
#
#    # pass:
#    # 1. supported commands
#    # 2. version which shall be shown in --version and --help
#    # 3. source command, responsible to load the files
#    # 4. the prefix used for the commands. e.g. command show with prefix my_lib_ results in calling a
#    #    function my_lib_show if the users wants to execute command show
#    # 5. arguments passed to the corresponding function
#    parseCommands commands "$MY_LIB_VERSION" sourceCommand "my_lib_" "$@"
#
#######	Limitations	#############
#
#	1. Does not support repeating arguments (last wins and overrides previous definitions)
#	2. Supports named arguments only (e.g. not possible to pass positional arguments after the named arguments)
#
#	=> take a look at https://github.com/ko1nksm/getoptions if you need something more powerful
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/array-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-utils.sh"

function parse_commands_describeParameterPair() {
	echo >&2 "The array needs to contain command definitions where a command definition consist of 2 values:"
	echo >&2 ""
	echo >&2 "commandName documentation"
	echo >&2 ""
	echo >&2 "...where documentation can also be an empty string (i.e. is kind of optional). Following an example of such an array:"
	echo >&2 ""
	cat >&2 <<-EOM
		declare commands=(
			config     'manages the configuration'
			calculate  'does the actual calculation'
		)
	EOM
}

function parse_commands_exitIfParameterDefinitionIsNotPair() {
	if (($# != 1)); then
		logError "One parameter needs to be passed to parse_commands_checkParameterDefinitionIsPair, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: params   the name of an array which contains the command definitions'
		printStackTrace
		exit 9
	fi

	exitIfArgIsNotArrayWithTuples "$1" 2 "command definitions" "first" "parse_commands_describeParameterPair"
}

function parseCommands {
	if (($# < 4)); then
		logError "At least five arguments need to be passed to parseCommands, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: commands   the name of an array which contains the command definitions'
		echo >&2 '2: version    the version which shall be shown if one uses --version'
		echo >&2 '3: sourceFn   the function which sources the necessary files for a particular command, the commandName will be passed to this function'
		echo >&2 '4: fnPrefix   prefix for the function representing a command'
		echo >&2 '5: command    the command name'
		echo >&2 '6... args...  arguments for the command, typically "$@"'
		printStackTrace
		exit 9
	fi

	local -rn parseCommands_paramArr=$1
	local -r version=$2
	local -r sourceFn=$3
	local -r fnPrefix=$4
	shift 4 || traceAndDie "could not shift by 4"

	if (($# < 1 )); then
		logError "no command passed to %s, following the output of --help\n" "$(basename "${BASH_SOURCE[1]}")"
		>&2 parse_commands_printHelp parseCommands_paramArr "$version"
		exit 9
	fi

	parse_commands_exitIfParameterDefinitionIsNotPair parseCommands_paramArr
	exitIfArgIsNotFunction "$sourceFn" 3

	local -r command=$1
	shift 1 || traceAndDie "could not shift by 1"
	local -a commandNames=()
	arrTakeEveryX parseCommands_paramArr commandNames 2 0 || return $?
	local tmpRegex regex
	tmpRegex=$(joinByChar "|" "${commandNames[@]}") || die "could not join commands by |, command names are %s" "${commandNames*}"
	regex="^($tmpRegex)\$"
	local -r tmpRegex regex

	if [[ "$command" =~ $regex ]]; then
		"$sourceFn" "$command" || traceAndDie "could not source necessary files to bring in function for command %s" "$command"
		"$fnPrefix${command/-/_}" "$@"
	elif [[ "$command" == "--help" ]]; then
		parse_commands_printHelp parseCommands_paramArr "$version"
	elif [[ "$command" == "--version" ]]; then
		printVersion "$version"
	else
		logError "unknown command \033[0;36m%s\033[0m, following the output of --help\n" "$command"
		>&2 parse_commands_printHelp parseCommands_paramArr "$version"
		return 1
	fi
}

function parse_commands_printHelp() {
	if (($# != 2)); then
		logError "Two arguments need to be passed to parse_commands_help, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: commands   the name of an array which contains the command definitions'
		echo >&2 '2: version    the version which shall be shown if one uses --version'
		printStackTrace
		exit 9
	fi

	# shellcheck disable=SC2034   # is passed by name to arrTakeEveryX
	local -rn parse_commands_printHelp_paramArr=$1
	local -r version=$2

	local -a commandNames=()
	arrTakeEveryX parse_commands_printHelp_paramArr commandNames 2 0 || return $?
	local -i maxLength=$(($(arrStringEntryMaxLength commandNames) + 2))
	local -ri arrLength="${#parseCommands_paramArr[@]}"

	printf "\033[1;33mCommands:\033[0m\n"
	local -i i
	for ((i = 0; i < arrLength; i += 2)); do
		local name="${parseCommands_paramArr[i]}"
		local help="${parseCommands_paramArr[i + 1]}"
		if [[ -n "$help" ]]; then
			printf "%-${maxLength}s %s\n" "$name" "$help"
		else
			echo "$name"
		fi
	done
	echo ""
	echo "--help     prints this help"
	echo "--version  prints the version of this script"
	echo ""
	printVersion "$version"
}
