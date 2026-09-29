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

# deduces nextVersion based on version if not already set (and if version set)
# shellcheck disable=SC2154   # it is assumed dir_of_tegonal_scripts is defined where this file is sourced
source "$dir_of_tegonal_scripts/releasing/deduce-next-version.source.sh" || traceAndDie "could not source deduce-next-version.source.sh"
source "$dir_of_tegonal_scripts/releasing/prepare-next-dev-cycle-template.params.source.sh" || traceAndDie "could not source prepare-next-dev-cycle-template.params.source.sh"
if ! [[ -v branch ]]; then branch="main"; fi
if ! [[ -v prepareOnly ]] || [[ $prepareOnly != "true" ]]; then prepareOnly=false; fi
if ! [[ -v beforePrFn ]]; then beforePrFn='beforePr'; fi
if ! [[ -v prepareNextDevCycleFn ]]; then prepareNextDevCycleFn='prepareNextDevCycle'; fi
