#!/usr/bin/env bash

# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
# into the default directory of this remote
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# pull the directory src/utility/ from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/

# pull the file src/utility/ask.sh from remote tegonal-scripts
# in the latest version and put into ./scripts/ instead of the default directory of this remote
# chop the repository path (i.e. src/utility), i.e. put ask.sh directly into ./scripts/
gt pull -r tegonal-scripts -p src/utility/ask.sh -d ./scripts/ --chop-path true

# pull the file src/utility/ask.sh from remote tegonal-scripts
# in the latest version and rename to asking.sh
gt pull -r tegonal-scripts -p src/utility/ask.sh --target-file-name asking.sh

# pull the file src/utility/checks.sh from remote tegonal-scripts
# in the latest version matching the specified tag-filter (i.e. one starting with v3)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/ --tag-filter "^v3.*"

# pull the file src/utility/checks.sh from remote tegonal-scripts in the latest version
# trust all gpg-keys stored in .gt/remotes/tegonal-scripts/public-keys
# if the remotes gpg sotre is not yet set up
gt pull -r tegonal-scripts --auto-trust true -p src/utlity/checks.sh

# pull the file src/utility/checks.sh from remote tegonal-scripts in the latest version
# Ignore if the gpg store of the remote is not set up and no suitable gpg key is defined in
# .gt/tegonal-scripts/public-keys. However, if the gpg store is setup or a suitable key is defined,
# then checks.sh will still be verified against it.
# (you might want to add --unsecure true to .gt/tegonal-scripts/pull.args if you never intend to
# set up gpg -- this way you don't have to repeat this option)
gt pull -r tegonal-scripts --unsecure true  -p src/utlity/checks.sh

# pull the file src/utility/checks.sh from remote tegonal-scripts in the latest version
# without verifying its signature (if defined) against the remotes gpg store
# you should not use this option unless you want to pull a file from a remote which signs files
# but has not signed the file you intend to pull.
gt pull -r tegonal-scripts --unsecure-no-verification true -p src/utlity/checks.sh

# pull the file src/utility/checks.sh from remote tegonal-scripts (in the custom working directory .github/.gt)
# in the latest version
gt pull -w .github/.gt -r tegonal-scripts -p src/utlity/checks.sh
