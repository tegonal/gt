#!/usr/bin/env bash

# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
# into the default directory of this remote
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# pull the directory src/utility/ from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/

# pull the file src/utility/ask.sh from remote tegonal-scripts
# from the latest version and put into ./scripts/ instead of the default directory of this remote
# chop the repository path (i.e. src/utility), i.e. put ask.sh directly into ./scripts/
gt pull -r tegonal-scripts -p src/utility/ask.sh -d ./scripts/ --chop-path true

# pull the file src/utility/checks.sh from remote tegonal-scripts
# from the latest version matching the specified tag-filter (i.e. one starting with v3)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/ --tag-filter "^v3.*"
