# shellcheck shell=bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
###################################
Describe 'working directory specs /'
	Include src/gt.sh
	Include lib/tegonal-scripts/src/utility/array-utils.sh

	# use once https://github.com/shellspec/shellspec/issues/259 is fixed
#	BeforeAll "commands_without_self_update"
	commands_without_self_update() {
		# shellcheck disable=SC2317		# passed by name to arrFilter
		function filterOutSelfUpdate() {
			! [[ $1 == "self-update" ]]
		}

		SPEC_HELPER_GT_COMMANDS_WITHOUT_SELF_UPDATE=()
		arrFilter SPEC_HELPER_GT_COMMANDS SPEC_HELPER_GT_COMMANDS_WITHOUT_SELF_UPDATE filterOutSelfUpdate
	}

	Parameters:value "${SPEC_HELPER_GT_COMMANDS_WITHOUT_SELF_UPDATE[@]}"
	It "gt $1 -w .."
		When run gt $1 -w ..
		The status should be failure
		The stderr should include "$(printf "the given \033[0;36mworking directory\033[0m %s is outside of %s" "$(realpath "$(pwd)/..")" "$(pwd)")"
	End
End
