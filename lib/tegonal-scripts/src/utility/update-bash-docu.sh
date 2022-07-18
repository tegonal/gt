#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.9.0
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
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    source "$dir_of_tegonal_scripts/utility/update-bash-docu.sh"
#
#    find . -name "*.sh" \
#    	-not -name "*.doc.sh" \
#    	-not -path "**.history/*" \
#    	-not -name "update-docu.sh" \
#    	-print0 |
#    	while read -r -d $'\0' script; do
#    		declare script="${script:2}"
#    		replaceSnippetForScript "$dir_of_tegonal_scripts/$script" "${script////-}" . README.md
#    	done
#
###################################
set -euo pipefail

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/parse-fn-args.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/replace-snippet.sh"

function updateBashDocumentation() {
	local script id dir pattern
	# shellcheck disable=SC2034
	local -ra params=(script id dir pattern)
	parseFnArgs params "$@"

	local snippet
	snippet=$(cat "${script::-3}.doc.sh")

	local quotedSnippet
	quotedSnippet=$(echo "$snippet" | perl -0777 -pe 's/(\/|\$|\\)/\\$1/g;' | sed 's/^/#    /' | sed 's/^#    $/#/')

	perl -0777 -i \
		-pe "s/(###+\s+Usage\s+###+\n#\n)[\S\s]+?(\n#\n###+)/\$1${quotedSnippet}\$2/g;" \
		"$script"

	replaceSnippet "$script" "$id" "$dir" "$pattern" "$(printf "\`\`\`bash\n%s\n\`\`\`" "$snippet")"
}
