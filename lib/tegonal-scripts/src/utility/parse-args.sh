#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.11.1
#
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
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
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
#    # in case you use shellcheck then you need to suppress the warning for the last variable definition of params
#    # as shellcheck doesn't get that we are passing `params` to parseArguments ¯\_(ツ)_/¯ (an open issue of shellcheck)
#    # shellcheck disable=SC2034
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
#    parseArguments params "$examples" "$@"
#    # in case there are optional parameters, then fill them in here before calling checkAllArgumentsSet
#    if ! [[ -v directory ]]; then directory="."; fi
#    checkAllArgumentsSet params "$examples"
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

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/recursive-declare-p.sh"

function describeParameterTriple() {
	echo >&2 "The array needs to contain parameter definitions where a parameter definition consist of 3 values:"
	echo >&2 ""
	echo >&2 "variableName pattern documentation"
	echo >&2 ""
	echo >&2 "...where documentation can also be an empty string (i.e. is kind of optional). Following an example of such an array:"
	echo >&2 ""
	cat >&2 <<-EOM
		declare params=(
			file '-f|--file' 'the file to use'
			isLatest '--is-Latest' ''
		)
	EOM
}

function checkParameterDefinitionIsTriple() {
	if ! (($# == 1)); then
		logError "One parameter needs to be passed to checkParameterDefinitionIsTriple, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1. params   the name of an array which contains the parameter definitions'
		printStackTrace
		exit 9
	fi

	local -rn paramArr2=$1
	local -r arrLength=${#paramArr2[@]}

	local arrayDefinition
	arrayDefinition="$(
		set -e
		recursiveDeclareP paramArr2
	)"
	reg='declare -a.*'
	if ! [[ "$arrayDefinition" =~ $reg ]]; then
		logError "the passed array \033[0;36m%s\033[0m is broken" "${!paramArr2}"
		echo >&2 "the first argument needs to be a non-associative array containing the parameter definitions, given:"
		echo >&2 "$arrayDefinition"
		echo >&2 ""
		describeParameterTriple
		printStackTrace
		return 9
	fi

	if ((arrLength == 0)); then
		logError "the passed array \033[0;36m%s\033[0m with parameter definitions is broken, length was 0\033[0m" "${!paramArr2}"
		describeParameterTriple
		printStackTrace
	fi

	if ! ((arrLength % 3 == 0)); then
		logError "the passed array \033[0;36m%s\033[0m with parameter definitions is broken" "${!paramArr2}"
		describeParameterTriple
		echo >&2 ""
		echo >&2 "given:"
		echo >&2 "$arrayDefinition"
		echo >&2 ""
		echo >&2 "following how we split this:"

		for ((i = 0; i < arrLength; i += 3)); do
			if ((i + 2 < arrLength)); then
				printf >&2 '"%s" "%s" "%s"\n' "${paramArr2[$i]}" "${paramArr2[$i + 1]}" "${paramArr2[$i + 2]}"
			else
				printf >&2 "\033[1;33mleftovers:\033[0m\n"
				printf >&2 '"%s"' "${paramArr2[$i]}"
				if ((i + 1 < arrLength)); then
					printf >&2 ' "%s"' "${paramArr2[$i + 1]}"
				fi
			fi
		done
		printStackTrace
		return 9
	fi
}

function parseArguments {
	if (($# < 3)); then
		logError "At least three arguments need to be passed to parseArguments, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1. params     the name of an array which contains the parameter definitions'
		echo >&2 '2. examples   a string containing examples (or an empty string)'
		echo >&2 '3. version    the version which shall be shown if one uses --version'
		echo >&2 '4... args...  the arguments as such, typically "$@"'
		printStackTrace
		exit 9
	fi

	local -rn parseArguments_paramArr1=$1
	local -r parseArguments_examples=$2
	local -r parseArguments_version=$3
	shift 3

	# we want to be sure that we return at this point even if someone has `set +e` thus the or clause
	# shellcheck disable=SC2310
	checkParameterDefinitionIsTriple parseArguments_paramArr1 || return $?

	local -r parseArguments_arrLength="${#parseArguments_paramArr1[@]}"

	local -i parseArguments_numOfArgumentsParsed=0
	while (($# > 0)); do
		parseArguments_argName="$1"
		if [[ $parseArguments_argName == --help ]]; then
			if ! ((parseArguments_numOfArgumentsParsed == 0)); then
				logWarning "there were arguments defined prior to --help, they will all be ignored and instead printHelp will be called"
			fi
			printHelp parseArguments_paramArr1 "$parseArguments_examples" "$parseArguments_version"
			return 99
		fi
		if [[ $parseArguments_argName == --version ]]; then
			if ! ((parseArguments_numOfArgumentsParsed == 0)); then
				logWarning "there were arguments defined prior to --version, they will all be ignored and instead printVersion will be called"
			fi
			printVersion "$parseArguments_version"
			return 99
		fi

		local -i parseArguments_expectedName=0
		for ((parseArguments_i = 0; parseArguments_i < parseArguments_arrLength; parseArguments_i += 3)); do
			local parseArguments_paramName="${parseArguments_paramArr1[parseArguments_i]}"
			local parseArguments_pattern="${parseArguments_paramArr1[parseArguments_i + 1]}"
			local parseArguments_regex="^($parseArguments_pattern)$"
			if [[ $parseArguments_argName =~ $parseArguments_regex ]]; then
				if (($# < 2)); then
					logError "no value defined for parameter \033[1;36m%s\033[0m (pattern %s) in %s" "$parseArguments_paramName" "$parseArguments_pattern" "${BASH_SOURCE[1]}"
					echo >&2 "following the help documentation:"
					echo >&2 ""
					printHelp >&2 parseArguments_paramArr1 "$parseArguments_examples" "$parseArguments_version"
					printStackTrace
					return 1
				fi
				# that's where the black magic happens, we are assigning to global variables here
				printf -v "$parseArguments_paramName" "%s" "$2"
				parseArguments_expectedName=1
				((++parseArguments_numOfArgumentsParsed))
				shift
			fi
		done

		if ((parseArguments_expectedName == 0)); then
			if [[ $parseArguments_argName =~ ^- ]] && (($# > 1)); then
				logWarning "ignored argument \033[1;36m%s\033[0m (and its value %s)" "$parseArguments_argName" "$2"
				shift
			else
				logWarning "ignored argument \033[1;36m%s\033[0m" "$parseArguments_argName"
			fi
		fi
		shift
	done
}

function printVersion() {
	if ! (($# == 1)); then
		logError "One argument needs to be passed to printVersion, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1. version   the version which shall be shown if one uses --version'
		printStackTrace
		exit 9
	fi
	local version=$1
	logInfo "Version of %s is:\n%s" "$(basename "${BASH_SOURCE[3]:-${BASH_SOURCE[2]}}")" "$version"
}

function printHelp {
	if ! (($# == 3)); then
		logError "Three arguments need to be passed to printHelp, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1. params    the name of an array which contains the parameter definitions'
		echo >&2 '2. examples  a string containing examples (or an empty string)'
		echo >&2 '3. version   the version which shall be shown if one uses --version'
		printStackTrace
		exit 9
	fi
	local -rn paramArr3=$1
	local -r examples=$2
	local -r version=$3

	# we want to be sure that we return at this point even if someone has `set +e` thus the or clause
	# shellcheck disable=SC2310
	checkParameterDefinitionIsTriple paramArr3 || return $?

	local arrLength="${#paramArr3[@]}"

	local maxLength=15
	for ((i = 0; i < arrLength; i += 3)); do
		local pattern="${paramArr3[i + 1]}"
		local length=$((${#pattern} + 2))
		if ((length > maxLength)); then
			maxLength="$length"
		fi
	done

	printf "\033[1;33mParameters:\033[0m\n"
	for ((i = 0; i < arrLength; i += 3)); do
		local pattern="${paramArr3[i + 1]}"
		local help="${paramArr3[i + 2]}"

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
	printVersion "$version"
}

function checkAllArgumentsSet {
	if ! (($# == 3)); then
		logError "Three arguments need to be passed to checkAllArgumentsSet, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1. params    the name of an array which contains the parameter definitions'
		echo >&2 '2. examples  a string containing examples (or an empty string)'
		echo >&2 '3. version    the version which shall be shown if one uses --version'
		printStackTrace
		exit 9
	fi

	# using unconventional naming in order to avoid name clashes with the variables we will check further below
	local -rn checkAllArgumentsSet_paramArr4=$1
	local -r checkAllArgumentsSet_examples=$2
	local -r checkAllArgumentsSet_version=$3

	# we want to be sure that we return at this point even if someone has `set +e` thus the or clause
	# shellcheck disable=SC2310
	checkParameterDefinitionIsTriple checkAllArgumentsSet_paramArr4 || return $?

	local -r checkAllArgumentsSet_arrLength="${#checkAllArgumentsSet_paramArr4[@]}"
	local -i checkAllArgumentsSet_good=1
	for ((checkAllArgumentsSet_i = 0; checkAllArgumentsSet_i < checkAllArgumentsSet_arrLength; checkAllArgumentsSet_i += 3)); do
		local checkAllArgumentsSet_paramName="${checkAllArgumentsSet_paramArr4[checkAllArgumentsSet_i]}"
		local checkAllArgumentsSet_pattern="${checkAllArgumentsSet_paramArr4[checkAllArgumentsSet_i + 1]}"
		if ! [[ -v "$checkAllArgumentsSet_paramName" ]]; then
			logError "%s not set via %s" "$checkAllArgumentsSet_paramName" "$checkAllArgumentsSet_pattern"
			checkAllArgumentsSet_good=0
		fi
	done
	if ((checkAllArgumentsSet_good == 0)); then
		echo >&2 ""
		echo >&2 "following the help documentation:"
		echo >&2 ""
		printHelp >&2 checkAllArgumentsSet_paramArr4 "$checkAllArgumentsSet_examples" "$checkAllArgumentsSet_version"
		if ((${#FUNCNAME} > 1)); then
			# it is handy to see the stacktrace if it is not a direct call from command line
			printStackTrace
		fi
		return 1
	fi
}
