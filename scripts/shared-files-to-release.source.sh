#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License 1.2
#         /___/                           Please report bugs and contribute back your improvements
#                                         Version: v0.17.0-SNAPSHOT
#######  Description  #############
#
#  constants intended to be sourced into additional-release-files-preparations.sh,
#  additional-prepare-files-next-dev-cycle-steps.sh etc.
#
###################################

local -ra additionalFilesWithVersions=(
		"$projectDir/.github/workflows/gt-update.yml"
	)

local -ra additionalScripts=(
	"$projectDir/install.sh"
	"$projectDir/.gt/remotes/tegonal-gh-commons/pull-hook.sh"
)
