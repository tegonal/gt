#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v1.0.0
#
#
#######  Description  #############
#
#  checks if there is a script.doc.sh next to the script.sh file, calls
#  replaceSnippet (from replace-snippet.sh) with its content
#  and updates the `Usage` section in script.sh accordingly

#  If your Usage section is currently empty, then make sure it has 3 empty `#` lines
#  otherwise it will not be replaced.
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    # Assumes tegonal's scripts were fetched with gt - adjust location accordingly
#    dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    source "$dir_of_tegonal_scripts/utility/update-bash-docu.sh"
#
#    find . -name "*.sh" \
#    	-not -name "*.doc.sh" \
#    	-print0 |
#    	while read -r -d $'\0' script; do
#    		declare script="${script:2}"
#    		updateBashDocumentation "$dir_of_tegonal_scripts/$script" "${script////-}" . README.md
#    	done
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/replace-snippet.sh"

function updateBashDocumentation() {
	local script id dir pattern
	# shellcheck disable=SC2034   # is passed to parseFnArgs by name
	local -ra params=(script id dir pattern)
	parseFnArgs params "$@"

	local snippet pathWithoutExtension
	pathWithoutExtension=${script::-3} || die "could not determine path without extension for script %s and %id" "$script" "$id"
	snippet=$(cat "${pathWithoutExtension}.doc.sh") || die "could not cat %s" "${pathWithoutExtension}.doc.sh"

	local quotedSnippet markdownSnippet
	quotedSnippet=$(perl -0777 -pe 's/(\/|\$|\\)/\\$1/g;' <<<"$snippet" | sed 's/^/#    /' | sed 's/^#    $/#/') || die "was not able to quote the snippet for script %s and id %s" "$script" "$id"
	markdownSnippet=$(printf "\`\`\`bash\n%s\n\`\`\`" "$snippet") || die "could not create the markdownSnippet for script %s and id %s" "$script" "$id"

	perl -0777 -i \
		-pe "s/(###+\s+Usage\s+###+\n#\n)[\S\s]+?(\n#\n###+)/\$1${quotedSnippet}\$2/g;" \
		"$script" || die "could not replace the Usage section for %s" "$script"

	replaceSnippet "$script" "$id" "$dir" "$pattern" "$markdownSnippet"
}
