# shellcheck shell=bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
###################################
Describe 'gt smoke tests'
	Include src/gt.sh

	It 'gt --help'
		When call gt --help
		The status should be successful
		The output should include 'Commands:'
		The output should include 'pull'
		The output should include 're-pull'
		The output should include 'remote'
		The output should include 'reset'
		The output should include 'update'
		The output should include 'self-update'
	End

	It 'gt remote --help'
		When call gt remote --help
		The status should be successful
		The output should include 'Commands:'
		The output should include 'add'
		The output should include 'remove'
		The output should include 'list'
	End

	Parameters:value pull re-pull reset update self-update 'remote add' 'remote remove' 'remote list'
	It "gt $1 --help"
		When call gt $1 --help
		The status should be successful
		The output should include 'Parameters'
		The output should include '--version'
		The output should include 'prints the version of this script'
		The output should include '--help'
		The output should include 'prints this help'
	End
End
