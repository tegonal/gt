#!/usr/bin/env bash

# updates all pulled files of all remotes to latest tag according to the tag-filter of the file
gt update

# updates all pulled files of remote tegonal-scripts to latest tag according to the tag-filter of the file
gt update -r tegonal-scripts

# updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0 if the tag-filter of the file matches,
# (i.e. a file with tag-filter v2.* would not be downgraded to v1.0.0).
# Side note, if no filter was specified during `gt pull`, then .* is used per default which includes all tags -- see
# pulled.tsv to see the current tagFilter in use per file
gt update -r tegonal-scripts -t v1.0.0

# lists the updatable files of remote tegonal-scripts
get update -r tegonal-scripts --list true
