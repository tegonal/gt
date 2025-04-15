#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.0
#######  Description  #############
#
#  constants intended to be sourced into a function
#
###################################

local -r versionRegex="^(v[0-9]+)\.([0-9]+)\.[0-9]+(-RC[0-9]+)?$"

local -r versionParamPatternLong='-v'
local -r versionParamPattern="$versionParamPatternLong"
local -r versionParamDocu='The version to release in the format vX.Y.Z(-RC...)'

local -r keyParamPatternLong='key'
local -r keyParamPattern="-k|$keyParamPatternLong"
local -r keyParamDocu='The GPG private key which shall be used to sign the files'

local -r findForSigningParamPatternLong='--sign-fn'
local -r findForSigningParamPattern="$findForSigningParamPatternLong"
local -r findForSigningParamDocu='Function which is called to determine what files should be signed. It should be based find and allow to pass further arguments (we will i.a. pass -print0)'

local -r branchParamPatternLong='--branch'
local -r branchParamPattern="-b|$branchParamPatternLong"
local -r branchParamDocu='(optional) The expected branch which is currently checked out -- default: main'

local -r projectsRootDirParamPatternLong='--project-dir'
local -r projectsRootDirParamPattern="$projectsRootDirParamPatternLong"
local -r projectsRootDirParamDocu='(optional) The projects directory -- default: .'

local -r additionalPatternParamPatternLong='--pattern'
local -r additionalPatternParamPattern="-p|$additionalPatternParamPatternLong"
local -r additionalPatternParamDocu='(optional) pattern which is used in a perl command (separator /) to search & replace additional occurrences. It should define two match groups and the replace operation looks as follows: '"\\\${1}\$version\\\${2}"

local -r nextVersionParamPatternLong='--next-version'
local -r nextVersionParamPattern="-nv|$nextVersionParamPatternLong"
local -r nextVersionParamDocu='(optional) the version to use for prepare-next-dev-cycle -- default: is next minor based on version'

local -r prepareOnlyParamPatternLong='--prepare-only'
local -r prepareOnlyParamPattern="$prepareOnlyParamPatternLong"
local -r prepareOnlyParamDocu='(optional) defines whether the release shall only be prepared (i.e. no push, no tag, no prepare-next-dev-cycle) -- default: false'

local -r forReleaseParamPatternLong='--for-release'
local -r forReleaseParamPattern="$forReleaseParamPatternLong"
local -r forReleaseParamDocu='true if update is for release in which case we hide the sneak-peek banner and toggle sections for release, if false then we show the sneak-peek banner and toggle the section for development'

local -r beforePrFnParamPatternLong='--before-pr-fn'
local -r beforePrFnParamPattern="$beforePrFnParamPatternLong"
local -r beforePrFnParamDocu="(optional) defines the function which is executed before preparing the release (to see if we should release) and after preparing the release -- default: beforePr (per convention defined in scripts/before-pr.sh). No arguments are passed"

local -r prepareNextDevCycleFnParamPatternLong='--prepare-next-dev-cycle-fn'
local -r prepareNextDevCycleFnParamPattern="$prepareNextDevCycleFnParamPatternLong"
local -r prepareNextDevCycleFnParamDocu="(optional) defines the function which is executed to prepare the next dev cycle -- default: perpareNextDevCycle (per convention defined in scripts/prepareNextDevCycle). \
The following arguments are passed: $versionParamPattern nextVersion $additionalPatternParamPatternLong additionalPattern $projectsRootDirParamPatternLong projectsRootDir $beforePrFnParamPatternLong beforePrFn"

local -r releaseHookParamPatternLong='--release-hook'
local -r releaseHookParamPattern="$releaseHookParamPatternLong"
local -r releaseHookParamDocu="performs the main release task such as (run tests) create artifacts, deploy artifacts"

local -r afterVersionUpdateHookParamPatternLong='--after-version-update-hook'
local -r afterVersionUpdateHookParamPattern="$afterVersionUpdateHookParamPatternLong"
local -r afterVersionUpdateHookParamDocu="(optional) if defined, then this function is called after versions were updated and before calling beforePr. \
The following arguments are passed: $versionParamPatternLong version $projectsRootDirParamPatternLong projectsRootDir and $additionalPatternParamPatternLong additionalPattern"

local -ra afterVersionHookParams=(
	version "$versionParamPattern" "$versionParamDocu"
	projectsRootDir "$projectsRootDirParamPattern" "$projectsRootDirParamDocu"
	additionalPattern "$additionalPatternParamPattern" "$additionalPatternParamDocu"
)
