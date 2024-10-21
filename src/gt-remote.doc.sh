#!/usr/bin/env bash

# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

# lists all existing remotes
gt remote list

# removes the remote tegonal-scripts again
gt remote remove -r tegonal-scripts
