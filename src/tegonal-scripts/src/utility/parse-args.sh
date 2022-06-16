#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#
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
#    declare -A params
#    declare -A help
#
#    # declare the variables where the arguments shall be stored (used as identifier afterwards)
#    declare directory pattern
#
#    # define the regex which is used to identify the argument `directory`
#    params[directory]='-d|--directory'
#    # optional: define an explanation for the argument `directory` which will show up in `--help`
#    help[directory]='(optional) the working directory -- default: .'
#
#    # in case you use shellcheck then you need to suppress the warning for the last variable definition of params
#    # as shellcheck doesn't get that we are passing `params` to parseArguments ¯\_(ツ)_/¯
#    # shellcheck disable=SC2034
#    params[pattern]='-p|--pattern'
#    # `help` is used implicitly in parse-args, here shellcheck cannot know it and you need to disable the rule
#    # shellcheck disable=SC2034
#    help[pattern]='pattern used during analysis'
#
#    # optional: you can define examples which are included in the help text
#    declare examples
#    # `examples` is used implicitly in parse-args, here shellcheck cannot know it and you need to disable the rule
#    # shellcheck disable=SC2034
#    examples=$(cat << EOM
#    # analyse in the current directory using the specified pattern
#    analysis.sh -p "%{21}"
#    EOM
#    )
#
#    declare current_dir
#    current_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
#    # Assuming parse-args.sh is in the same directory as your script
#    source "$current_dir/parse-args.sh"
#
#    parseArguments params "$@"
#    # in case there are optional parameters, then fill them in here before calling checkAllArgumentsSet
#    if ! [ -v directory ]; then directory="."; fi
#    checkAllArgumentsSet params
#
#    # pass your variables storing the arguments to other scripts
#    echo "d: $directory, p: $pattern"
#
#######  Limitations  #############
#
#  1. Does not support repeating arguments (last wins and overrides previous definitions)
#  2. Supports named arguments only (e.g. not possible to pass positional arguments after the named arguments)
#
###################################

set -e

function parseArguments {
  local -n parameterNames=$1
  shift

  while [[ $# -gt 0 ]]; do
    argName="$1"
    expectedName=0
    for paramName in "${!parameterNames[@]}"; do
      regex="^(${parameterNames[$paramName]})$"
      if [[ "$argName" =~ $regex ]]; then
        # that's where the black magic happens, we are assigning to global variables here
        printf -v "${paramName}" "%s" "$2"
        expectedName=1
        shift
      fi
    done
    if [[ "$argName" == "--help" ]]; then
      printHelp parameterNames
      exit 0
    fi
    if [ "$expectedName" -eq 0 ]; then
      if [[ "$argName" =~ ^- ]]; then
        printf "\033[1;33mignored argument %s (and its value)\033[0m\n" "$argName"
      fi
    fi
    shift
  done
}

function printHelp {
  local -n names=$1
  printf "\n\033[1;33mParameters:\033[0m\n"
  for paramName in "${!names[@]}"; do
    if [[ -v help[@] ]] && [ "${help[$paramName]+_}" ] ; then
      printf "%-20s %s\n" "${names[$paramName]}" "${help[$paramName]}"
    else
      echo "${names[$paramName]} $help"
    fi
  done
  if [ -v examples ]; then
    printf "\n\033[1;33mExamples:\033[0m\n"
    echo "$examples"
  fi
}

function checkAllArgumentsSet {
  local -n parameterNames=$1
  local good=1
  for paramName in "${!parameterNames[@]}"; do
    if ! [ -v "$paramName" ]; then
      printf >&2 "\033[1;31mERROR: %s not set\n\033[0m" "$paramName"
      good=0
    fi
  done
  if [ "$good" -eq 0 ]; then
    echo >&2 ""
    echo >&2 "following the help documentation:"
    printHelp >&2 parameterNames
    echo >&2 ""
    echo >&2 "use --help to see this list"
    exit 1
  fi
}
