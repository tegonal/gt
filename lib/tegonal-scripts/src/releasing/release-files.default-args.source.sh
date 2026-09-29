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
# defines what default values the params should get if not already defined
#
###################################

# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
source "$dir_of_tegonal_scripts/releasing/release-template.default-args.source.sh"

# currently release-files defines not more optional params than release-template, hence the above is enough
