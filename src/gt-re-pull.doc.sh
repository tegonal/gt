#!/usr/bin/env bash

# for each remote in .gt
# - re-pull files defined in .gt/remotes/<remote>/pulled.tsv which are missing locally
gt re-pull

# re-pull files defined in .gt/remotes/tegonal-scripts/pulled.tsv which are missing locally
gt re-pull -r tegonal-scripts

# pull all files defined in .gt/remotes/tegonal-scripts/pulled.tsv regardless if they already exist locally or not
gt re-pull -r tegonal-scripts --only-missing false

# uses a custom working directory and re-pulls files of remote tegonal-scripts which are missing locally
gt re-pull -r tegonal-scripts -w .github/.gt
