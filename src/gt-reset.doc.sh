#!/usr/bin/env bash

# resets all defined remotes, which means for each remote in .gt
# - re-initialise gpg trust based on public keys defined in .gt/remotes/<remote>/public-keys/*.asc
# - pull files defined in .gt/remotes/<remote>/pulled.tsv
gt reset

# resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .gt/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .gt/remotes/tegonal-scripts/pulled.tsv
gt reset -r tegonal-scripts

# only re-initialise gpg trust based on public keys defined in .gt/remotes/tegonal-scripts/public-keys/*.asc
gt reset -r tegonal-scripts --gpg-only true

# uses a custom working directory and resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .github/.gt/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .github/.gt/remotes/tegonal-scripts/pulled.tsv
gt reset -w .github/.gt -r tegonal-scripts
