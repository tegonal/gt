#!/usr/bin/env bash

current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"

# Assuming gget-remote.sh is in the same directory as your script -- though, usually you would use: gget remote ...

# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
"$current_dir/gget-remote.sh" add -r tegonal-scripts -u https://github.com/tegonal/scripts

# lists all existing remotes
"$current_dir/gget-remote.sh" list

# removes the remote tegonal-scripts again
"$current_dir/gget-remote.sh" remove -r tegonal-scripts
