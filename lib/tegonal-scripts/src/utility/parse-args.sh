#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.4.0
#
#######  Description  #############
#
#  Intended to parse command line arguments. Provides a simple way to parse named arguments including a documentation
#  if one uses the parameter `--help`
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    # declare the variables where the arguments shall be stored (used as identifier afterwards)
#    declare directory pattern version
#
#    # parameter definitions where each parameter definition consists of three values (separated via space)
#    # VARIABLE_NAME PATTERN HELP_TEXT
#    # where the HELP_TEXT is optional in the sense of that you can use an empty string
#    # in case you use shellcheck then you need to suppress the warning for the last variable definition of params
#    # as shellcheck doesn't get that we are passing `params` to parseArguments ¯\_(ツ)_/¯ (an open issue of shellcheck)
#    # shellcheck disable=SC2034
#    declare params=(
#    	directory '-d|--directory' '(optional) the working directory -- default: .'
#    	pattern '-p|--pattern' 'pattern used during analysis'
#    	version '-v|--version' ''
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
#    declare scriptDir
#    scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#    # Assuming parse-args.sh is in the same directory as your script
#    source "$scriptDir/parse-args.sh"
#
#    parseArguments params "$examples" "$@"
#    # in case there are optional parameters, then fill them in here before calling checkAllArgumentsSet
#    if ! [ -v directory ]; then directory="."; fi
#    checkAllArgumentsSet params "$examples"
#
#    # pass your variables storing the arguments to other scripts
#    echo "d: $directory, p: $pattern, v: $version"
#
#######	Limitations	#############
#
#	1. Does not support repeating arguments (last wins and overrides previous definitions)
#	2. Supports named arguments only (e.g. not possible to pass positional arguments after the named arguments)
#
#	=> take a look at https://github.com/ko1nksm/getoptions if you need something more powerful
#
###################################

set -e

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
		printf >&2 "\033[1;31mERROR\033[0m: One parameter needs to be passed to checkParameterDefinitionIsTriple\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]}"
		echo >&2 '1. params		 an array with the parameter definitions'
		return 9
	fi

	local -n paramArr2=$1
	local arrLength=${#paramArr2[@]}

	local arrayDefinition
	arrayDefinition=$(declare -p paramArr2)
	local reg='^declare -n [^=]+=\"([^\"]+)\"$'
	while [[ $arrayDefinition =~ $reg ]]; do
		arrayDefinition=$(declare -p "${BASH_REMATCH[1]}")
	done
	reg='declare -a.*'
	if ! [[ "$arrayDefinition" =~ $reg ]]; then
		printf >&2 "\033[1;31mERROR: array with parameter definitions is broken\033[0m for \033[1;34m%s\033[0m in %s\n" "${!paramArr2}" "${BASH_SOURCE[2]}"
		echo >&2 "the first argument needs to be a non-associative array, given:"
		echo >&2 "$arrayDefinition"
		echo >&2 ""
		describeParameterTriple
		return 9
	fi

	if ((arrLength == 0)); then
		printf >&2 "\033[1;31mERROR:array with parameter definitions is broken, length was 0\033[0m in %s\n" "${BASH_SOURCE[2]}"
		describeParameterTriple
	fi

	if ! ((arrLength % 3 == 0)); then
		printf >&2 "\033[1;31mERROR: array with parameter definitions is broken\033[0m for \033[1;34m%s\033[0m in %s\n" "${!paramArr2}" "${BASH_SOURCE[2]}"
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
		return 9
	fi
}

function parseArguments {
	if (($# < 2)); then
		printf >&2 "\033[1;31mERROR\033[0m: At least two arguments need to be passed to parseArguments.\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]}"
		echo >&2 '1. params		 an array with the parameter definitions'
		echo >&2 '2. examples	 a string containing examples (or an empty string)'
		echo >&2 '3... args...	the arguments as such, typically "$@"'
		return 9
	fi

	local -n paramArr1=$1
	local examples=$2
	shift 2

	checkParameterDefinitionIsTriple paramArr1 || return $?

	local arrLength="${#paramArr1[@]}"

	while (($# > 0)); do
		argName="$1"
		if [[ "$argName" == "--help" ]]; then
			printHelp paramArr1 "$examples"
			return 99
		fi

		expectedName=0
		for ((i = 0; i < arrLength; i += 3)); do
			local paramName="${paramArr1[i]}"
			local pattern="${paramArr1[i + 1]}"
			regex="^($pattern)$"
			if [[ "$argName" =~ $regex ]]; then
				# that's where the black magic happens, we are assigning to global variables here
				if [ -z "$2" ]; then
					printf >&2 "\033[1;31mERROR\033[0m: no value defined for parameter \033[1;34m%s\033[0m in %s\n" "$pattern" "${BASH_SOURCE[1]}"
					echo >&2 "following the help documentation:"
					echo >&2 ""
					printHelp >&2 paramArr1 "$examples"
					return 1
				fi
				printf -v "${paramName}" "%s" "$2"
				expectedName=1
				shift
			fi
		done

		if ((expectedName == 0)); then
			if [[ "$argName" =~ ^- ]]; then
				printf "\033[1;33mWARNING: ignored argument %s (and its value %s)\033[0m\n" "$argName" "$2"
				shift
			else
				printf "\033[1;33mWARNING: ignored argument %s\033[0m\n" "$argName"
			fi
		fi
		shift
	done
}

function printHelp {
	if ! (($# == 2)); then
		printf >&2 "\033[1;31mERROR\033[0m: Two arguments need to be passed to printHelp.\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]}"
		echo >&2 '1. params		 an array with the parameter definitions'
		echo >&2 '2. examples	 a string containing examples (or an empty string)'
		return 9
	fi
	local -n paramArr3=$1
	local examples=$2
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
	if [ -n "$examples" ]; then
		printf "\n\033[1;33mExamples:\033[0m\n"
		echo "$examples"
	fi
}

function checkAllArgumentsSet {
	if ! (($# == 2)); then
		printf >&2 "\033[1;31mERROR\033[0m: Two arguments need to be passed to checkAllArgumentsSet.\nGiven \033[0;36m%s\033[0m in \033[0;36m%s\033[0m\nFollowing a description of the parameters:\n" "$#" "${BASH_SOURCE[1]}"
		echo >&2 '1. params		 an array with the parameter definitions'
		echo >&2 '2. examples	 a string containing examples (or an empty string)'
		return 9
	fi
	local -n paramArr4=$1
	local examples=$2
	checkParameterDefinitionIsTriple paramArr4 || return $?

	local arrLength="${#paramArr4[@]}"
	local good=1
	for ((i = 0; i < arrLength; i += 3)); do
		local paramName="${paramArr4[i]}"
		if ! [ -v "$paramName" ]; then
			printf >&2 "\033[1;31mERROR\033[0m: %s not set\n" "$paramName"
			good=0
		fi
	done
	if ((good == 0)); then
		echo >&2 ""
		echo >&2 "following the help documentation:"
		printHelp >&2 paramArr4 "$examples"
		echo >&2 ""
		echo >&2 "use --help to see this list"
		return 1
	fi
}
