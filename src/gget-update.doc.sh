#!/usr/bin/env bash

# updates all pulled files of all remotes to latest tag
gget update

# updates all pulled files of remote tegonal-scripts to latest tag
gget update -r tegonal-scripts

# updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
gget update -r tegonal-scripts -t v1.0.0
