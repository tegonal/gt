#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gt
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        Copyright 2022 Tegonal Genossenschaft <info@tegonal.com>
#  \__/\__/\_, /\___/_//_/\_,_/_/         It is licensed under European Union Public License v. 1.2
#         /___/                           Please report bugs and contribute back your improvements
#
#                                         Version: v0.19.0
#######  Description  #############
#
#  utility to include the content of install.doc.sh into given files (e.g. into other scripts or github workflow files
#  etc.)
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#
#    if ! [[ -v dir_of_gt ]]; then
#    	# Assumes copy-install-doc.sh was fetched with gt - adjust location accordingly
#    	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/gt/src"
#    fi
#    sourceOnce "$dir_of_gt/install/copy-install-doc.sh"
#
#    # e.g. could be used in cleanup-on-push-to-main.sh
#
#    function cleanupOnPushToMain() {
#    	# shellcheck disable=SC2034   # is passed by name to copyInstallDoc
#    	local -ar includeInstallDoc=(
#    	  # file_name indent
#    		"$projectDir/.github/workflows/gt-update.yml" '          '
#      	"$projectDir/src/gitlab/install-gt.sh" ''
#    	)
#    	copyInstallDoc "$dir_of_gt/../install.doc.sh" includeInstallDoc
#    }
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
export GT_VERSION='v0.19.0'

if ! [[ -v dir_of_gt ]]; then
	dir_of_gt="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	readonly dir_of_gt
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_gt/../lib/tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/checks.sh"

function includeInstallDoc() {
	if ! (($# == 2)); then
		logError "Exactly two arguments need to be passed to includeInstallDoc, given \033[0;36m%s\033[0m\nFollowing a description of the parameters:" "$#"
		echo >&2 '1: installDocSh    path to the install.doc.sh'
		echo >&2 '2: files           array of pairs where the first element in the pair is the file in which the install.doc.sh shall be included and the second is the indent which shall be used'
		printStackTrace
		exit 9
	fi

	# using unconventional naming in order to avoid name clashes with the variables we will initialise further below
	local -r installDocSh=$1
	local -rn includeInstallDoc_files=$2
	shift 2 || die "could not shift by 2"

	if ! [[ -f "$installDocSh" ]]; then
		returnDying "%s does not exist" "$installDocSh"
	fi

	# shellcheck disable=SC2317   # is passed by name to exitIfArgIsNotArrayWithTuples
	function describePair() {
		echo >&2 "array contains pairs of files where the install.doc.sh shall be included. The first value of the pair is the path to the file and the second the indent which shall be used"
	}

	exitIfArgIsNotArrayWithTuples includeInstallDoc_files 2 "files" 2 describePair

	local installScript
	installScript=$(perl -0777 -pe 's/(@|\$|\\)/\\$1/g;' <"$installDocSh")

	local -r arrLength="${#includeInstallDoc_files[@]}"
	local -i i
	for ((i = 0; i < arrLength; i += 2)); do
		local file="${includeInstallDoc_files[i]}"
		if ! [[ -f $file ]]; then
			returnDying "file $file does not exist" || return $?
		fi

		local indent="${includeInstallDoc_files[i + 1]}"
		local content
		# shellcheck disable=SC2001	# cannot use search/replace variable substitution here
		content=$(sed "s/^/$indent/g" <<<"$installScript") || return $?
		perl -0777 -i \
			-pe "s@(\n\s+# see install.doc.sh.*\n)[^#]+(# end install.doc.sh\n)@\${1}$content\n$indent\${2}@g" \
			"$file" || return $?
	done || die "could not replace the install instructions"
}

${__SOURCED__:+return}
includeInstallDoc "$@"
