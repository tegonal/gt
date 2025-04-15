#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under Apache License 2.0
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v4.8.0
#######  Description  #############
#
#  utility function dealing with fetching files via http
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    sourceOnce "$dir_of_tegonal_scripts/utility/http.sh"
#
#    # downloads https://.../signing-key.public.asc and https://.../signing-key.public.asc.sig and verifies it with gpg
#    wgetAndVerify "https://github.com/tegonal/gt/.gt/signing-key.public.asc"
#
###################################
set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "please update to bash 5, see errors above" && exit 1; }
unset CDPATH
export TEGONAL_SCRIPTS_VERSION='v4.8.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

function wgetAndVerify() {
	exitIfCommandDoesNotExist "wget"

	local url gpgDir
	# shellcheck disable=SC2034   # is passed by name to parseArguments
	local -ar params=(
		url "-u|--url" "the url which shall be fetched"
		gpgDir "--gpg-homedir" "(optional) can be used to specify a different home directory for gpg -- default: \$HOME/.gnupg"
	)
	local -r examples=$(
		# shellcheck disable=SC2312		# cat shouldn't fail for a constant string hence fine to ignore exit code
		cat <<-EOM
			# downloads https://.../signing-key.public.asc and https://.../signing-key.public.asc.sig and verifies it with gpg
      wgetAndVerify "https://github.com/tegonal/gt/.gt/signing-key.public.asc"
		EOM
	)
	parseArguments params "$examples" "$TEGONAL_SCRIPTS_VERSION" "$@" || return $?
	if ! [[ -v gpgDir ]]; then gpgDir="$HOME/.gnupg"; fi
	exitIfNotAllArgumentsSet params "$examples" "$TEGONAL_SCRIPTS_VERSION"

	local fileName
	fileName=$(basename "$url") || die "could not determine file name of %s" "$url"
	local currentDir
	currentDir=$(pwd) || die "could not determine currentDir via pwd"

	for name in "$fileName" "$fileName.sig"; do
	if [[ -f $name ]]; then
  		logInfo "there is already a file named %s in %s, going to override" "$name" "$currentDir"
  	fi
	done

	wget -O "$url" || die "could not download %s" "$url"
	wget -O "$url.sig" || die "could not download %s" "$url.sig"
	gpg --homedir "$gpgDir" --verify "./$fileName.sig" "./$fileName"
}
