<!-- for main -->

[![Download](https://img.shields.io/badge/Download-v0.4.0-%23007ec6)](https://github.com/tegonal/gget/releases/tag/v0.4.0)
[![Apache 2.0](https://img.shields.io/badge/%E2%9A%96-Apache%202.0-%230b45a6)](http://opensource.org/licenses/Apache2.0 "License")
[![Code Quality](https://github.com/tegonal/gget/workflows/Code%20Quality/badge.svg?event=push&branch=main)](https://github.com/tegonal/gget/actions/workflows/code-quality.yml?query=branch%3Amain)
[![Newcomers Welcome](https://img.shields.io/badge/%F0%9F%91%8B-Newcomers%20Welcome-blueviolet)](https://github.com/tegonal/gget/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22 "Ask in discussions for help")

<!-- for main end -->
<!-- for release -->
<!--
[![Download](https://img.shields.io/badge/Download-v0.4.0-%23007ec6)](https://github.com/tegonal/gget/releases/tag/v0.4.0)
[![Apache 2.0](https://img.shields.io/badge/%E2%9A%96-Apache%202.0-%230b45a6)](http://opensource.org/licenses/Apache2.0 "License")
[![Newcomers Welcome](https://img.shields.io/badge/%F0%9F%91%8B-Newcomers%20Welcome-blueviolet)](https://github.com/tegonal/gget/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22 "Ask in discussions for help")
-->
<!-- for release end -->
# gget

g(it)get is a bash based script which pulls a file or a directory stored in a git repository.
It includes automatic verification via GPG signature.  
It enables that files can be maintained at a single places and pulled into multiple projects (e.g. scripts, config files etc.)
In this sense, gget is a bit like a package manager which is based on git repositories but without dependency resolution and such.

<details>
<summary>The initial idea behind this project:</summary>

You have scripts you use in multiple projects and would like to have a single place where you maintain them.
Maybe you even made them public so that others can use them as well 
(as we have done with [Tegonal scripts](https://github.com/tegonal/scripts)).
This tool provides an easy way to fetch them into your project.

Likewise, you can use gget to pull config files, templates etc. which you use in multiple projects but want to maintain 
at a single place.

</details>

---

❗ You are taking a _sneak peek_ at the next version.
Please have a look at the README of the git tag in case you are looking for the documentation of the corresponding version.
For instance, the [README of v0.4.0](https://github.com/tegonal/gget/tree/v0.4.0/README.md).

---

**Table of Content**
- [Installation](#installation)
  - [install.sh](#using-installsh)
  - [manually](#manually)
- [Usage](#usage)
  - [remote](#remote)
    - [add](#add)
    - [remove](#remove)
    - [list](#list)
  - [pull](#pull) 
    - [Pull Hook](#pull-hook)
  - [re-pull](#re-pull)
  - [reset](#reset)
  - [self-update](#self-update)
- [Contributors and contribute](#contributors-and-contribute)
- [License](#license)

# Installation

## using install.sh

This script downloads the latest or a specific tag of gget and verifies gget's files against 
the current GPG key (the one in the main branch).

We suggest that you download install.sh and its *.sig file and 
verify the two against our GPG key before actually running it:
```
! [ -f ./install.sh ] || { echo "there is already an install.sh in your directory, aborting"; return 1 } && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh.sig" && \
wget -O- https://raw.githubusercontent.com/tegonal/gget/main/.gget/signing-key.public.asc | gpg --import - && \
gpg --verify ./install.sh.sig ./install.sh && \
chmod +x ./install.sh && \
echo "verification successful" || { echo "verification failed, don't continue"; return 99 } 
```

<details>
<summary>click here for an explanation of each command</summary>

1. `! [ -f ./install.sh ]`  
   We don't want to override an existing `./install.sh` thus we check if there is already one and abort if this is the case
2. `wget .../install.sh`  
   download the install.sh
3. `wget .../install.sh.sig`  
   download the signature file of install.sh
4. `wget .../signing-key.public.asc | gpg --import -`  
   import the current public key of gget
5. `gpg --verify...`  
   verify the install.sh you downloaded is (still) valid
6. `chmod +x ./install.sh`  
   make install.sh executable
7. `echo "..."`  
   output the result of the verification

</details>

If successful you can install gget by just calling `./install.sh` (you might want to remove it afterwards)

Per default, it downloads the latest tag and installs it into `$HOME/.local/lib/gget` 
and sets up a symbolic link at `$HOME/.local/bin/gget`.

You can tweak this behaviour as shown as follows:
```
# Download the latest tag, configure default installation directory and symbolic link
install.sh

# Download a specific tag, default installation directory and symbolic link
install.sh -t v0.3.0

# Download latest tag but custom installation directory, without the creation of a symbolic link
install.sh -d /opt/gget

# Download latest tag but custom installation directory and symlink
install.sh -d /opt/gget -ln /usr/local/bin
```

Last but not least, see [additional installation steps](#additional-installation-steps)

## manually

1. [![Download](https://img.shields.io/badge/Download-v0.4.0-%23007ec6)](https://github.com/tegonal/gget/releases/tag/v0.4.0)
2. extract the zip/tar.gz 
3. open a terminal at the corresponding folder and verify the scripts against our public key:  
   ```bash
   wget -O- https://raw.githubusercontent.com/tegonal/gget/main/.gget/signing-key.public.asc | gpg --import -
   find ./src -name "*.sig" -print0 | while read -r -d $'\0' sig; do gpg --verify "$sig"; done && echo "verification successful" || echo "verification failed, don't continue"
   ```  
4. copy the src directory to a place where you want to store gget:
   1. For instance, if you only want it for the current user, then place it into $HOME/.local/lib/gget
   2. if it shall be available for all users, then place it e.g. in /opt/gget or
   3. into your project directory in case you want that other contributors can use it as well without an own installation
5. optional: create a symlink:
   1. only for the current user `ln -s "$HOME/.local/lib/gget/src/gget.sh" "$HOME/.local/bin/gget"`
   2. globally `ln -s "$HOME/.local/lib/gget/src/gget.sh" "/usr/local/bin/gget"`
   3. in project: `ln -s ./lib/gget/src/get.sh ./gget`
6. See [additional installation steps](#additional-installation-steps)

## additional installation steps

Typically you add the following to your .gitignore file:
```gitignore
.gget/**/repo
.gget/**/gpg
```

# Usage

Following the output of running `gget --help`:

<gget-help>

<!-- auto-generated, do not modify here but in src/gget.sh -->
```text
Commands:
pull          pull files from a previously defined remote
re-pull       re-pull files defined in pulled.tsv of a specific or all remotes
remote        manage remotes
reset         reset one or all remotes (re-establish gpg and re-pull files)
self-update   update gget to the latest version

--help     prints this help
--version  prints the version of this script

INFO: Version of gget.sh is:
v0.5.0-SNAPSHOT
```

</gget-help>

## remote

Use this command to manage remotes.
Following the output of running `gget remote --help`:

<gget-remote-help>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```text
Commands:
add      add a remote
remove   remove a remote
list     list all remotes

--help     prints this help
--version  prints the version of this script

INFO: Version of gget-remote.sh is:
v0.5.0-SNAPSHOT
```

</gget-remote-help>

Some examples (see documentation of each sub command in subsection for more details):

<gget-remote>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```bash
#!/usr/bin/env bash

# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

# lists all existing remotes
gget remote list

# removes the remote tegonal-scripts again
gget remote remove -r tegonal-scripts
```

</gget-remote>

## add

Following the output of running `gget remote add --help`:

<gget-remote-add-help>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```text
Parameters:
-r|--remote              name to refer to this the remote repository
-u|--url                 url of the remote repository
-d|--directory           (optional) directory into which files are pulled -- default: lib/<remote>
--unsecure               (optional) if set to true, the remote does not need to have GPG key(s) defined at .gget/*.asc -- default: false
-w|--working-directory   (optional) path which gget shall use as working directory -- default: .gget

--help     prints this help
--version  prints the version of this script

Examples:
# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
# uses the default location lib/tegonal-scripts for the files which will be pulled from this remote
gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

# uses a custom pull directory, files of the remote tegonal-scripts will now
# be placed into scripts/lib/tegonal-scripts instead of default location lib/tegonal-scripts
gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -d scripts/lib/tegonal-scripts

# Does not complain if the remote does not provide a GPG key for verification (but still tries to fetch one)
gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts --unsecure true

# uses a custom working directory
gget remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -w .github/.gget

INFO: Version of gget-remote.sh is:
v0.2.0-SNAPSHOT
```

</gget-remote-add-help>

### remove

Following the output of running `gget remote remove --help`:

<gget-remote-remove-help>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```text
Parameters:
-r|--remote              define the name of the remote which shall be removed
-w|--working-directory   (optional) path which gget shall use as working directory -- default: .gget

--help     prints this help
--version  prints the version of this script

Examples:
# removes the remote tegonal-scripts
gget remote remove -r tegonal-scripts

# uses a custom working directory
gget remote remove -r tegonal-scripts -w .github/.gget

INFO: Version of gget-remote.sh is:
v0.2.0-SNAPSHOT
```

</gget-remote-remove-help>

### list

Following the output of running `gget remote list --help`:

<gget-remote-list-help>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```text
Parameters:
-w|--working-directory   (optional) path which gget shall use as working directory -- default: .gget

--help     prints this help
--version  prints the version of this script

Examples:
# lists all defined remotes in .gget
gget remote list

# uses a custom working directory
gget remote list -w .github/.gget

INFO: Version of gget-remote.sh is:
v0.2.0-SNAPSHOT
```

</gget-remote-list-help>

## pull

Use this command to pull files from a previously defined remote (see [remote -> add](#add)).

Following the output of running `gget pull --help`:

<gget-pull-help>

<!-- auto-generated, do not modify here but in src/gget-pull.sh -->
```text
Parameters:
-r|--remote                  name of the remote repository
-t|--tag                     git tag used to pull the file/directory
-p|--path                    path in remote repository which shall be pulled (file or directory)
-d|--directory               (optional) directory into which files are pulled -- default: pull directory of this remote (defined during "remote add" and stored in .gget/<remote>/pull.args)
--chop-path                  (optional) if set to true, then files are put into the pull directory without the path specified. For files this means they are put directly into the pull directory
-w|--working-directory       (optional) path which gget shall use as working directory -- default: .gget
--auto-trust                 (optional) if set to true, all public-keys stored in .gget/remotes/<remote>/public-keys/*.asc are imported without manual consent -- default: false
--unsecure                   (optional) if set to true, the remote does not need to have GPG key(s) defined in gpg databse or at .gget/<remote>/*.asc -- default: false
--unsecure-no-verification   (optional) if set to true, implies --unsecure true and does not verify even if gpg keys are in store or at .gget/<remote>/*.asc -- default: false

--help     prints this help
--version  prints the version of this script

Examples:
# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# pull the directory src/utility/ from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/

# pull the file .github/CODE_OF_CONDUCT.md and put it into the pull directory .github
# without repeating the path (option --chop-path), i.e is pulled directly into .github/CODE_OF_CONDUCT.md
# and not into .github/.github/CODE_OF_CONDUCT.md
gget pull -r tegonal-scripts -t v0.1.0 -d .github --chop-path true -p .github/CODE_OF_CONDUCT.md

INFO: Version of gget-pull.sh is:
v0.5.0-SNAPSHOT
```

</gget-pull-help>

Full usage example:

<gget-pull>

<!-- auto-generated, do not modify here but in src/gget-pull.sh -->
```bash
#!/usr/bin/env bash

# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# pull the directory src/utility/ from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/
```

</gget-pull>

### pull hook

You can define the file `pull-hook.sh` in `WORKGIN_DIR/remotes/REMOTE/pull-hook.sh` 
(for instance in `.gget/remotes/tegonal-scripts/pull-hook.sh`), 
make it executable and it will be called for each file which is pulled where the following arguments are passed:
1. tag specified via `-t|--target`
2. path of the file before the move to its target destination
3. target destination

For instance, a hook could look as follows:
```bash
#!/usr/bin/env bash
set -eu -o pipefail
declare tag=$1 source=$2 target=$3
shift 3
echo "before moving $source of tag $tag to $target"
```

## re-pull

Use this command to pull missing files form all or a specific remote. You can also use it to re-pull files even if they
already exist locally.

Following the output of running `gget re-pull --help`:

<gget-re-pull-help>

<!-- auto-generated, do not modify here but in src/gget-re-pull.sh -->
```text
Parameters:
-r|--remote              (optional) if set, only the remote with this name is reset, otherwise all are reset
-w|--working-directory   (optional) path which gget shall use as working directory -- default: .gget
--auto-trust             (optional) if set to true, all public-keys stored in .gget/remotes/<remote>/public-keys/*.asc are imported without manual consent -- default: false
--only-missing           (optional) if set, then only files which do not exist locally are pulled, otherwise all are re-pulled -- default: true

--help     prints this help
--version  prints the version of this script

Examples:
# re-pull all files of remote tegonal-scripts which are missing locally
gget re-pull -r tegonal-scripts

# re-pull all files of all remotes which are missing locally
gget re-pull

# re-pull all files (not only missing) of remote tegonal-scripts, imports gpg keys without manual consent if necessary
gget re-pull -r tegonal-scripts --only-missing false --auto-trust true

INFO: Version of gget-re-pull.sh is:
v0.5.0-SNAPSHOT
```

</gget-re-pull-help>

Full usage example:

<gget-re-pull>

<!-- auto-generated, do not modify here but in src/gget-re-pull.sh -->
```bash
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
```

</gget-re-pull>

## reset

Use this command to reset one or all remotes. By resetting we mean, re-establish trust (check GPG key again) and 
re-fetch all files.

Following the output of running `gget reset --help`:

<gget-reset-help>

<!-- auto-generated, do not modify here but in src/gget-reset.sh -->
```text
Parameters:
-r|--remote              (optional) if set, only the remote with this name is reset, otherwise all are reset
-w|--working-directory   (optional) path which gget shall use as working directory -- default: .gget
--auto-trust             (optional) if set to true, all public-keys stored in .gget/remotes/<remote>/public-keys/*.asc are imported without manual consent -- default: false

--help     prints this help
--version  prints the version of this script

Examples:
# reset the remote tegonal-scripts
gget reset -r tegonal-scripts

# resets all remotes
gget reset

# resets all remotes and imports gpg keys without manual consent
gget reset --auto-trust true

INFO: Version of gget-reset.sh is:
v0.5.0-SNAPSHOT
```

</gget-reset-help>

Full usage example:

<gget-reset>

<!-- auto-generated, do not modify here but in src/gget-reset.sh -->
```bash
#!/usr/bin/env bash

# resets all defined remotes, which means for each remote in .gget
# - re-initialise gpg trust based on public keys defined in .gget/remotes/<remote>/public-keys/*.asc
# - pull files defined in .gget/remotes/<remote>/pulled.tsv
gget reset

# resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .gget/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .gget/remotes/tegonal-scripts/pulled.tsv
gget reset -r tegonal-scripts

# uses a custom working directory and resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .github/.gget/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .github/.gget/remotes/tegonal-scripts/pulled.tsv
gget reset -r tegonal-scripts -w .github/.gget
```

</gget-reset>

# self-update

You can update gget by using gget (which in turn uses its install.sh)

<gget-self-update>

<!-- auto-generated, do not modify here but in src/gget-self-update.sh -->
```bash
#!/usr/bin/env bash

# update gget to the latest version
gget self-update
```

</gget-self-update>

# Contributors and contribute

Our thanks go to [code contributors](https://github.com/tegonal/gget/graphs/contributors)
as well as all other contributors (e.g. bug reporters, feature request creators etc.)

You are more than welcome to contribute as well:
- star this repository if you like/use it
- [open a bug](https://github.com/tegonal/gget/issues/new?template=bug_report.md) if you find one
- Open a [new discussion](https://github.com/tegonal/gget/discussions/new?category=ideas) if you are missing a feature
- [ask a question](https://github.com/tegonal/gget/discussions/new?category=q-a)
  so that we better understand where our scripts need to improve.
- have a look at the [help wanted issues](https://github.com/tegonal/gget/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
  if you would like to code.

# License

gget is licensed under [Apache 2.0](http://opensource.org/licenses/Apache2.0).
