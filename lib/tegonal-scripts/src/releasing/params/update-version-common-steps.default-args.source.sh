#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v5.1.0
#######  Description  #############
#
# Defines default args for ...params-definition.source.sh for files which use the same arguments but allow optional
# parameters (the afterVersionUpdateHook as such should not)
#
###################################

# Note, it is used in prepare-next-dev-cycle-template.default-args.source.sh, if you should add default args
# which are only relevant for update-version-common-steps then don't re-use in
# prepare-next-dev-cycle-template.default-args.source.sh any more.
if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath ".") || die "could not determine realpath of ."; fi
if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
