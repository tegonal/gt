#!/usr/bin/env bash

# resets all defined remotes, which means for each remote in .gget
# - re-initialise gpg trust based on public keys defined in .gget/remotes/<remote>/public-keys/*.asc
# - pull files defined in .gget/remotes/<remote>/pulled
gget reset

# resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .gget/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .gget/remotes/tegonal-scripts/pulled
gget reset -r tegonal-scripts

# uses a custom working directory and resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .github/.gget/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .github/.gget/remotes/tegonal-scripts/pulled
gget reset -r tegonal-scripts -w .github/.gget
