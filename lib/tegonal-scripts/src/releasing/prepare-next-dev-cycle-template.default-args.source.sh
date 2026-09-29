#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.13.0-SNAPSHOT
#######  Description  #############
#
# defines default args for ...params-definition.source.sh
#
###################################

# Note, it is used in release-template.default-args.source.sh, if you should add default args which are only relevant
# for prepare-next then don't re-use in release-template.default-args any more.
if ! [[ -v projectsRootDir ]]; then projectsRootDir=$(realpath ".") || die "could not determine realpath of ."; fi
if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
if ! [[ -v beforePrFn ]]; then beforePrFn='beforePr'; fi
if ! [[ -v afterVersionUpdateHook ]]; then afterVersionUpdateHook=''; fi
