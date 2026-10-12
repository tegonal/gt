#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.12.0
#######  Description  #############
#
#  Checks if (env) var SONATYPE_USER and SONATYPE_PW is set and if not ask the user to input them (via stdin).
#  Afterwards it calls `sbt publishSigned` passing the variables without exporting them.
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
#
#    # ask for SONATYPE_USER and SONATYPE_PW (unless already exported beforehand) and calls sbt publishSigned
#    "$dir_of_tegonal_scripts/releasing/sbt-publish-to-sonatype.sh"
#
#    # predefine SONATYPE_USER, asks for SONATYPE_PW (unless already exported beforehand) and calls sbt publishSigned
#    SONATYPE_USER="kshjwo2" "$dir_of_tegonal_scripts/releasing/sbt-publish-to-sonatype.sh"
#
#    # if you use it in combination with other files, then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/sbt-publish-to-sonatype.sh"
#
#    # and then call the function
#    sbtPublishToSonatype
#    SONATYPE_USER="kshjwo2" sbtPublishToSonatype
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.12.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup_tegonal_scripts.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"

function sbtPublishToSonatype() {
	local askWithTimeout=60

	# shellcheck disable=SC2317   # called by name
	function sbtPublishToSonatype_noAnswerCallback() {
		printf "\n"
		die "no user interaction after %s seconds, stop publish process'." "askWithTimeout"
	}

	if ! [[ -v SONATYPE_USER ]] || [[ -z "$SONATYPE_USER" ]]; then
		askWithTimeout "Please enter the sonatype user token (input is hidden -- will be written to SONATYPE_USER):" \
			"$askWithTimeout" sbtPublishToSonatype_noAnswerCallback SONATYPE_USER "-s"
	else
		logInfo "SONATYPE_USER already defined"
	fi

	if ! [[ -v SONATYPE_PW ]] || [[ -z "$SONATYPE_PW" ]]; then
		askWithTimeout "Please enter the sonatype access token (input is hidden -- will be written to SONATYPE_PW):" \
			"$askWithTimeout" sbtPublishToSonatype_noAnswerCallback SONATYPE_PW "-s"
	else
		logInfo "$SONATYPE_PW already defined"
	fi
	printf "\n"
	SONATYPE_PW="$SONATYPE_PW" SONATYPE_USER="$SONATYPE_USER" sbt publishSigned
}

${__SOURCED__:+return}
sbtPublishToSonatype "$@"
