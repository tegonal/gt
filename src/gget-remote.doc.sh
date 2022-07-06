#!/usr/bin/env bash

# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

# lists all existing remotes
gget remote list

# removes the remote tegonal-scripts again
gget remote remove -r tegonal-scripts
