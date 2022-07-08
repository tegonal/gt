#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.1.0-SNAPSHOT
#
#######  Description  #############
#
#  internal utility functions
#  no backward compatibility guarantees or whatsoever
#
###################################

function deleteDirChmod777() {
	local -r dir=$1
	# e.g files in .git will be write-protected and we don't want sudo for this command
	chmod -R 777 "$dir"
	rm -r "$dir"
}

function findAscInDir() {
	local -r dir=$1
	shift
	find "$dir" -maxdepth 1 -type f -name "*.asc" "$@"
}

function noAscInDir() {
	local -r dir=$1
	shift 1
	(($(findAscInDir "$dir" | wc -l) == 0))
}
