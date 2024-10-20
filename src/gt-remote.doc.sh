#!/usr/bin/env bash

# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

# adds the remote test with url https://github.com/tegonal/test
# specifying that this repo has most likely no GPG keys setup -- if so,
# then --unsecure true is added to the pull.args
gt remote add -r test -u https://github.com/tegonal/test --unsecure true

# adds the remote tegonal-gh-commons with url https://github.com/tegonal/github-commons
# specifying that only tags matching the given tag-filter shall be considered when
# determining the latest version (when using `gt pull` or `gt update` without specifying a tag)
gt remote add -r tegonal-gh-commons -u https://github.com/tegonal/github-commons --tag-filter "^commons-.*" true


# lists all existing remotes
gt remote list

# removes the remote tegonal-scripts again
gt remote remove -r tegonal-scripts
