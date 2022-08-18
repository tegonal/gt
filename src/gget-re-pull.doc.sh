#!/usr/bin/env bash

# for each remote in .gget
# - re-pull files defined in .gget/remotes/<remote>/pulled.tsv which are missing locally
gget re-pull

# re-pull files defined in .gget/remotes/tegonal-scripts/pulled.tsv which are missing locally
gget re-pull -r tegonal-scripts

# pull all files defined in .gget/remotes/tegonal-scripts/pulled.tsv regardless if they already exist locally or not
gget re-pull -r tegonal-scripts --only-missing false

# uses a custom working directory and re-pulls files of remote tegonal-scripts which are missing locally
gget re-pull -r tegonal-scripts -w .github/.gget
