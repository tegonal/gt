#!/usr/bin/env bash

current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"

# Assuming gget.sh is in the same directory as your script
"$current_dir/gget.sh" -r tegonal-scripts -u https://github.com/tegonal/scripts \
	-t v0.1.0 -p src/utility/update-bash-docu.sh \
	-d "$current_dir/tegonal-scripts"
