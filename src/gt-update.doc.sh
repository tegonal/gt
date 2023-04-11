#!/usr/bin/env bash

# updates all pulled files of all remotes to latest tag
gt update

# updates all pulled files of remote tegonal-scripts to latest tag
gt update -r tegonal-scripts

# updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
gt update -r tegonal-scripts -t v1.0.0
