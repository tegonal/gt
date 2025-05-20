#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.1
#######  Description  #############
#
#  Intended to parse command line arguments. Provides a simple way to parse named arguments including a documentation
#  if one uses the parameter `--help` and shows the version if one uses --version.
#  I.e. that also means that `--help` and `--version` are reserved patterns and should not be used by your
#  script/function.
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
#    sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
#
#    # declare all parameter names here (used as identifier afterwards)
#    declare pattern version directory
#
#    # parameter definitions where each parameter definition consists of three values (separated via space)
#    # VARIABLE_NAME PATTERN HELP_TEXT
#    # where the HELP_TEXT is optional in the sense of that you can use an empty string
#    # shellcheck disable=SC2034   # is passed by name to parseArguments
#    declare params=(
#    	pattern '-p|--pattern' ''
#    	version '-v' 'the version'
#    	directory '-d|--directory' '(optional) the working directory -- default: .'
#    )
#    # optional: you can define examples which are included in the help text -- use an empty string for no example
#    declare examples
#    # `examples` is used implicitly in parse-args, here shellcheck cannot know it and you need to disable the rule
#    examples=$(
#    	cat <<EOM
#    # analyse in the current directory using the specified pattern
#    analysis.sh -p "%{21}" -v v0.1.0
#    EOM
#    )
#
#    parseArguments params "$examples" "$MY_LIB_VERSION" "$@" || return $?
#    # in case there are optional parameters, then fill them in here before calling exitIfNotAllArgumentsSet
#    if ! [[ -v directory ]]; then directory="."; fi
#    exitIfNotAllArgumentsSet params "$examples" "$MY_LIB_VERSION"
#
#    # pass your variables storing the arguments to other scripts
#    echo "p: $pattern, v: $version, d: $directory"
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
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-utils.sh"

function parse_args_describeParameterTriple() {
	echo >&2 "The array needs to contain parameter definitions where a parameter definition consist of 3 values:"
	echo >&2 ""
	echo >&2 "variableName pattern documentation"
	echo >&2 ""
	echo >&2 "...where documentation can also be an empty string (i.e. is kind of optional)."
	echo >&2 "Following an example of such an array:"
	echo >&2 ""
	cat >&2 <<-EOM
		declare params=(
			file '-f|--file' 'the file to use'
			isLatest '--is-Latest' ''
		)
	EOM
}

function parse_args_exitIfParameterDefinitionIsNotTriple() {
	if (($# != 1)); then
		logError "One argument needs to be passed to parse_args_exitIfParameterDefinitionIsNotTriple, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: params   the name of an array which contains the parameter definitions'
		printStackTrace
		exit 9
	fi

	exitIfArgIsNotArrayWithTuples "$1" 3 "parameter definitions" "first" "parse_args_describeParameterTriple"
}
function parseArgumentsIgnoreUnknown {
	parseArgumentsInternal 'ignore' "$@"
}

function parseArguments {
	parseArgumentsInternal 'error' "$@"
}

function parseArgumentsInternal {
	if (($# < 4)); then
		logError "At least three arguments need to be passed to parseArguments, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: unknownBehaviour   one of: error, ignore'
		echo >&2 '2: params     				the name of an array which contains the parameter definitions'
		echo >&2 '3: examples   				a string containing examples (or an empty string)'
		echo >&2 '4: version    			 	the version which shall be shown if one uses --version'
		echo >&2 '5... args...  				the arguments as such, typically "$@"'
		printStackTrace
		exit 9
	fi

	local -r parseArguments_unknownBehaviour=$1
	local -rn parseArguments_paramArr=$2
	local -r parseArguments_examples=$3
	local -r parseArguments_version=$4
	shift 4 || traceAndDie "could not shift by 4"

	if ! [[ "$parseArguments_unknownBehaviour" =~ ^(ignore|error)$ ]]; then
		traceAndDie "unknownBehaviour needs to be one of 'error' or 'ignore' got \033[0;36m%s\033[0m" "$parseArguments_unknownBehaviour"
	fi

	parse_args_exitIfParameterDefinitionIsNotTriple parseArguments_paramArr

	# shellcheck disable=SC2034		# passed by name to exitIfVariablesNotDeclared
	local -a parseArguments_variableNames
	arrTakeEveryX parseArguments_paramArr parseArguments_variableNames 3 0 || return $?
	exitIfVariablesNotDeclared "${parseArguments_variableNames[@]}"

	local -ri parseArguments_arrLength="${#parseArguments_paramArr[@]}"

	function parseArgumentsInternal_ask_printHelp() {
		if askYesOrNo >&2 "Shall I print the help for you?"; then
			parseArgumentsInternal_printHelp >&2
		fi
	}

	function parseArgumentsInternal_printHelp() {
		parse_args_printHelp parseArguments_paramArr "$parseArguments_examples" "$parseArguments_version" 5
	}

	local -i parseArguments_numOfArgumentsParsed=0
	while (($# > 0)); do
		parseArguments_argName="$1"
		if [[ $parseArguments_argName == --help ]]; then
			parseArgumentsInternal_printHelp
			if ! ((parseArguments_numOfArgumentsParsed == 0)); then
				logWarning "there were arguments defined prior to --help, they were all ignored and instead the help is shown"
			elif (($# > 1)); then
				logWarning "there were arguments defined after --help, they will all be ignored, you might want to remove --help"
			fi
			return 99
		fi
		if [[ $parseArguments_argName == --version ]]; then
			if ! ((parseArguments_numOfArgumentsParsed == 0)); then
				logWarning "there were arguments defined prior to --version, they will all be ignored and instead printVersion will be called"
			fi
			printVersion "$parseArguments_version" 4
			return 99
		fi

		local -i parseArguments_expectedName=0
		local -i parseArguments_i
		for ((parseArguments_i = 0; parseArguments_i < parseArguments_arrLength; parseArguments_i += 3)); do
			local parseArguments_paramName="${parseArguments_paramArr[parseArguments_i]}"
			local parseArguments_pattern="${parseArguments_paramArr[parseArguments_i + 1]}"
			local parseArguments_regex="^($parseArguments_pattern)$"
			if [[ $parseArguments_argName =~ $parseArguments_regex ]]; then
				if (($# < 2)); then
					logError "no value defined for parameter \033[1;36m%s\033[0m (pattern %s) in %s" "$parseArguments_paramName" "$parseArguments_pattern" "${BASH_SOURCE[2]}"
					printStackTrace
					parseArgumentsInternal_ask_printHelp
					exit 9
				fi
				assignToVariableInOuterScope "$parseArguments_paramName" "$2" || die "could not to assign a value to variable in outer scope named %s" "$parseArguments_paramName"
				parseArguments_expectedName=1
				((++parseArguments_numOfArgumentsParsed))
				shift 1 || traceAndDie "could not shift by 1"
			fi
		done

		if [[ $parseArguments_unknownBehaviour = 'error' ]] && ((parseArguments_expectedName == 0)); then
			if [[ $parseArguments_argName =~ ^- ]] && (($# > 1)); then
				logError "unknown argument \033[1;36m%s\033[0m (and value %s)" "$parseArguments_argName" "$2"
			else
				logError "unknown argument \033[1;36m%s\033[0m" "$parseArguments_argName"
			fi
			parseArgumentsInternal_ask_printHelp
			exit 9
		fi
		shift 1 || traceAndDie "could not shift by 1"
	done
}

function parse_args_printHelp {
	if (($# != 4)); then
		logError "Three arguments need to be passed to parse_args_printHelp, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: params       the name of an array which contains the parameter definitions'
		echo >&2 '2: examples     a string containing examples (or an empty string)'
		echo >&2 '3: version      the version which shall be shown if one uses --version'
		echo >&2 '4: stackFrame   number of frames to drop to determine the source of the call'
		printStackTrace
		exit 9
	fi
	local -rn parse_args_printHelp_paramArr=$1
	local -r examples=$2
	local -r version=$3
	local -r stackFrame=$4
	shift 4 || traceAndDie "could not shift by 4"

	parse_args_exitIfParameterDefinitionIsNotTriple parse_args_printHelp_paramArr

	local arrLength="${#parse_args_printHelp_paramArr[@]}"

	# shellcheck disable=SC2034   # is passed by name to arrStringEntryMaxLength
	local -a patterns=()
	arrTakeEveryX parse_args_printHelp_paramArr patterns 3 1 || return $?
	local -i maxLength=$(($(arrStringEntryMaxLength patterns) + 2))

	printf "\033[1;33mParameters:\033[0m\n"
	local -i i
	for ((i = 0; i < arrLength; i += 3)); do
		local pattern="${parse_args_printHelp_paramArr[i + 1]}"
		local help="${parse_args_printHelp_paramArr[i + 2]}"

		if [[ -n "$help" ]]; then
			printf "%-${maxLength}s %s\n" "$pattern" "$help"
		else
			echo "$pattern"
		fi
	done
	echo ""
	echo "--help     prints this help"
	echo "--version  prints the version of this script"

	if [[ -n $examples ]]; then
		printf "\n\033[1;33mExamples:\033[0m\n"
		echo "$examples"
	fi
	echo ""
	printVersion "$version" "$stackFrame"
}

function exitIfNotAllArgumentsSet {
	if (($# != 3)) && (($# != 4)); then
		logError "Three arguments need to be passed to exitIfNotAllArgumentsSet, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: params    						the name of an array which contains the parameter definitions'
		echo >&2 '2: examples 						a string containing examples (or an empty string)'
		echo >&2 '3: version    					the version which shall be shown if one uses --version'
		echo >&2 '4: printStackTraceFrom	(optional) defines from how many calls we show the stacktrace -- default 3 '
		printStackTrace
		exit 9
	fi

	# using unconventional naming in order to avoid name clashes with the variables we will check further below
	local -rn exitIfNotAllArgumentsSet_paramArr=$1
	local -r exitIfNotAllArgumentsSet_examples=$2
	local -r exitIfNotAllArgumentsSet_version=$3
	shift 3 || traceAndDie "could not shift by 3"

	# it is handy to see the stacktrace if it is not a direct call from command line
	# where we assume that the script as such has a "main" function, this one calls one function from this file and
	# this calls exitIfNotAllArgumentsSet i.e. if we have more than 3 calls, then we are not directly from command line
	local -r printStackTraceIfMoreThan=${1:-3}

	parse_args_exitIfParameterDefinitionIsNotTriple exitIfNotAllArgumentsSet_paramArr

	local -ri exitIfNotAllArgumentsSet_arrLength="${#exitIfNotAllArgumentsSet_paramArr[@]}"
	local -i exitIfNotAllArgumentsSet_good=1 exitIfNotAllArgumentsSet_i
	for ((exitIfNotAllArgumentsSet_i = 0; exitIfNotAllArgumentsSet_i < exitIfNotAllArgumentsSet_arrLength; exitIfNotAllArgumentsSet_i += 3)); do
		local exitIfNotAllArgumentsSet_paramName="${exitIfNotAllArgumentsSet_paramArr[exitIfNotAllArgumentsSet_i]}"
		local exitIfNotAllArgumentsSet_pattern="${exitIfNotAllArgumentsSet_paramArr[exitIfNotAllArgumentsSet_i + 1]}"
		if [[ -v "$exitIfNotAllArgumentsSet_paramName" ]]; then
			readonly "$exitIfNotAllArgumentsSet_paramName"
		else
			logError "%s not set via %s" "$exitIfNotAllArgumentsSet_paramName" "$exitIfNotAllArgumentsSet_pattern"
			exitIfNotAllArgumentsSet_good=0
		fi
	done
	if ((exitIfNotAllArgumentsSet_good == 0)); then
		echo >&2 ""
		echo >&2 "following the help documentation:"
		echo >&2 ""
		parse_args_printHelp >&2 exitIfNotAllArgumentsSet_paramArr "$exitIfNotAllArgumentsSet_examples" "$exitIfNotAllArgumentsSet_version" 5
		if ((${#FUNCNAME[@]} > printStackTraceIfMoreThan)); then
			printStackTrace
		fi
		exit 1
	fi
}
