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
#  Utility functions to ask the user something via input.
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
#    sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
#
#    if askYesOrNo "shall I say hello"; then
#    	echo "hello"
#    fi
#
#    function noAnswerCallback {
#    	echo "hm... no answer, I am sad :("
#    }
#    timeoutInSeconds=30
#    readArgs='' # i.e. no additional args passed to read
#    answer='default value used if there is no answer'
#    askWithTimeout "some question" "$timeoutInSeconds" noAnswerCallback answer "$readArgs"
#    echo "$answer"
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"

function askYesOrNo() {
	if (($# == 0)); then
		logError "At least one argument needs to be passed to askYesOrNo, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: question   the question which the user should answer with y or n'
		echo >&2 '2... args...  arguments for the question (question is printed with printf)'
		printStackTrace
		exit 9
	fi
	local -r question=$1
	shift 1 || traceAndDie "could not shift by 1"

	local -r askYesOrNo_timeout=20
	local answer='n'

	# shellcheck disable=SC2317   # called by name
	function askYesOrNo_noAnswerCallback() {
		printf "\n"
		logInfo "no user interaction after %s seconds, going to interpret that as a 'no'." "$askYesOrNo_timeout"
	}

	# shellcheck disable=SC2059			# the question itself can have %s thus we use it in the format string
	askWithTimeout "\033[0;36m$question\033[0m y/[n]:" "$askYesOrNo_timeout" askYesOrNo_noAnswerCallback answer "" "$@"
	if [[ $answer == y ]] || [[ $answer == Y ]] || [[ $answer == yes ]]; then
		return 0
	elif [[ $answer == n ]] || [[ $answer == N ]] || [[ $answer == no ]]; then
		return 1
	else
		logWarning "got \033[0;36m%s\033[0m as answer (instead of y for yes or n for no), interpreting it as a n, i.e. as a no" "$answer"
		return 1
	fi
}

function askWithTimeout() {
	if (($# < 5)); then
		logError "At least five arguments need to be passed to askWithTimeout, given \033[0;36m%s\033[0m\n" "$#"
		echo >&2 '1: question   	the question which the user should answer'
		echo >&2 '2: timeout			timeout in seconds after which we will call noAnswerFn'
		echo >&2 '3: noAnswerFn		callback used in case we did not get an answer from the user'
		echo >&2 '4: outVarName		name of output variable used to pass back the result'
		echo >&2 '5: readArgs 		additional args passed to read'
		echo >&2 '6... args...  	arguments for the question (question is printed with printf)'
		printStackTrace
		exit 9
	fi
	# prefixing all variables here as plan to write the answer to an variable which is not in scope of this function
	# i.e. if we don't prefix and one using the same name for outVarName as a variable local to this function, then we
	# would just assign a value to the local function instead of the variable defined outside this function. The prefix
	# prevents such a clash in most likely all cases -- otherwise the user is to blame ;)
	local -r askWithTimeout_question=$1
	local -r askWithTimeout_timeout=$2
	local -r askWithTimeout_noAnswerFn=$3
	local -r askWithTimeout_outVarName=$4
	local -r askWithTimeout_readArgs=$5
	shift 5 || traceAndDie "could not shift by 5"

	exitIfArgIsNotFunction "$askWithTimeout_noAnswerFn" 3
	# shellcheck disable=SC2059			# the question itself can have %s thus we use it in the format string
	printf "\n$askWithTimeout_question " "$@"
	local askWithTimeout_answer=''
	set +e
	if [[ -n $askWithTimeout_readArgs ]]; then
		read -t "$askWithTimeout_timeout" "${askWithTimeout_readArgs?}" -r askWithTimeout_answer
	else
		read -t "$askWithTimeout_timeout" -r askWithTimeout_answer
	fi

	local askWithTimeout_lastResult=$?
	set -e
	if ((askWithTimeout_lastResult > 128)); then
		"$askWithTimeout_noAnswerFn"
	elif [[ $askWithTimeout_lastResult -eq 0 ]]; then
		# that's where the black magic happens, we are assigning to a global (not local to this function) variable here
		printf -v "$askWithTimeout_outVarName" "%s" "$askWithTimeout_answer" || die "could not assign value to $askWithTimeout_outVarName"
	else
		return "$askWithTimeout_lastResult"
	fi
}
