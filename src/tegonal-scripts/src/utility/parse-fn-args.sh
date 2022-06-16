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
# script which is supposed to be sourced and checks that enough arguments are provided and assigns to defined variables
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#
#    function myFunction() {
#      # declare the variable you want to use and repeat in `declare args`
#      declare command dir
#
#      # args is used in parse-fn-args.sh thus:
#      # shellcheck disable=SC2034
#      declare args=(command dir)
#
#      # Assuming parse-fn-args.sh is in the same directory as your script
#      current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#      . "$current_dir/parse-fn-args.sh"
#
#      # pass your variables storing the arguments to other scripts
#      echo "command: $command, dir: $dir"
#    }
#
#    function myFunctionWithVarargs() {
#
#      # in case you want to use a vararg parameter as last parameter then name your last parameter for `args` varargs:
#
#      declare command dir varargs
#      # shellcheck disable=SC2034
#      declare args=(command dir varargs)
#
#      # Assuming parse-fn-args.sh is in the same directory as your script
#      current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"
#      . "$current_dir/parse-fn-args.sh"
#
#      # use varargs in another script
#      echo "${varargs[0]}"
#
#    }
#
#######  Limitations  #############
#
#  1. Does not support named arguments (see parse-args.sh if you want named arguments for your function)
#
###################################

set -e

if ! [[ -v args[@] ]]; then
  echo >&2 "parse-fn-args.sh requires you to define an array named 'args', for instance as follows"
  echo >&2 "declare args=(variableStoringArg1 variableStoringArg2)"
  exit 2
fi

declare withVarArgs
withVarArgs=$(declare -p "varargs" >/dev/null 2>&1)

if [ "${#args[@]}" -lt "$#"  ]; then
  printf >&2 "Not enough arguments supplied to \033[0m\033[0;36m%s\033[0m: expected %s, given %s\nFollowing a listing of the arguments (red means missing):\n" "${FUNCNAME[1]}" "${#args[@]}" "$#"

  declare -i i=1
  for name in "${args[@]}"; do
    printf "\033[0m"
    if ((i - 1 < $#)); then
      printf "\033[0;32m"
    else
      printf "\033[0;31m"
    fi
    printf >&2 "%2s: %s\n" "$i" "$name"
    ((i = i + 1))
  done
  printf "\033[0m"
  exit 1
fi

if ! [ "$withVarArgs" ] && ! [ "$#" -eq "${#args[@]}" ]; then
  printf >&2 "more arguments supplied than expected to \033[0m\033[0;36m%s\033[0m: expected %s, given %s\n" "${FUNCNAME[1]}" "${#args[@]}" "$#"
  echo >&2 "in case you wanted your last parameter to be a vararg parameter, then use 'vararg' as last variable name in 'args'"
  exit 1
fi

# assign arguments to specified variables
for name in "${args[@]}"; do
  declare "$name"="$1"
  shift
done

# assign rest to varags if declared
if $withVarArgs; then
  # is used afterwards
  # shellcheck disable=SC2034
  varargs=( "$@" )
fi
