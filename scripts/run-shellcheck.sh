#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#
#
set -eu

declare scriptDir
scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"

declare foundIssues=false

while read -r -d $'\0' script; do
	declare output=
	output=$(shellcheck -C -s bash -S info -x -o all -e SC2312 -P "$scriptDir/../src/" "$script" || true)
	if ! [ "$output" == "" ]; then
		printf "%s\n" "$output"
		foundIssues=true
	fi
done < <(find "$scriptDir/../src" "$scriptDir/../scripts" -name '*.sh' -not -path "**tegonal-scripts/*" -print0)

if [ "$foundIssues" == true ]; then
	printf >&2 "\033[1;31mERROR\033[0m: found shellcheck issues, aborting"
	exit 1
fi
