<!-- for main -->

[![Download](https://img.shields.io/badge/Download-v0.17.3-%23007ec6)](https://github.com/tegonal/gt/releases/tag/v0.17.3)
[![EUPL](https://img.shields.io/badge/%E2%9A%96-EUPL%201.2-%230b45a6)](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12 "License")
[![Quality Assurance](https://github.com/tegonal/gt/actions/workflows/quality-assurance.yml/badge.svg?event=push&branch=main)](https://github.com/tegonal/gt/actions/workflows/quality-assurance.yml?query=branch%3Amain)
[![Newcomers Welcome](https://img.shields.io/badge/%F0%9F%91%8B-Newcomers%20Welcome-blueviolet)](https://github.com/tegonal/gt/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22 "Ask in discussions for help")

<!-- for main end -->
<!-- for release -->
<!--
[![Download](https://img.shields.io/badge/Download-v0.17.3-%23007ec6)](https://github.com/tegonal/gt/releases/tag/v0.17.3)
[![EUPL](https://img.shields.io/badge/%E2%9A%96-EUPL%201.2-%230b45a6)](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12 "License")
[![Newcomers Welcome](https://img.shields.io/badge/%F0%9F%91%8B-Newcomers%20Welcome-blueviolet)](https://github.com/tegonal/gt/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22 "Ask in discussions for help")
-->
<!-- for release end -->

# gt

g(it)t(ools) is a bash based script which pulls a file or a directory stored in a git repository.
It includes automatic verification via GPG.  
It enables that files can be maintained at a single place and pulled into multiple projects (e.g. scripts, config files
etc.)
In this sense, gt is a bit like a package manager which is based on git repositories but without dependency resolution
and such.

<details>
<summary>The initial idea behind this project:</summary>

You have scripts you use in multiple projects and would like to have a single place where you maintain them.
Maybe you even made them public so that others can use them as well
(as we have done with [Tegonal scripts](https://github.com/tegonal/scripts)).
This tool provides an easy way to pull them into your project.

Likewise, you can use gt to pull other kind of scripts (not only bash scripts, e.g. gradle scripts), config files, 
templates etc. which you use in multiple projects but want to maintain at a single place.

</details>

---
❗ You are taking a *sneak peek* at the next version. It could be that some features you find on this page are not released yet.  
Please have a look at the README of the corresponding release/git tag. Latest version: [README of v0.17.3](https://github.com/tegonal/gt/tree/v0.17.3/README.md).

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
	- [update](#update)
		- [GitHub Workflow](#github-workflow)
        - [Gitlab Job](#gitlab-job) <!-- if you change this anchor then update src/gitlab/install-gt.sh -->
	- [self-update](#self-update)
- [FAQ](#faq)
- [Contributors and contribute](#contributors-and-contribute)
- [License](#license)

# Installation

## using install.sh

`intall.sh` downloads the latest or a specific tag of gt and verifies gt's files against
the current GPG key (the one in the main branch).

We suggest you verify install.sh against the public key of this repository and
the public key of this repository against
[Tegonal's public key for github](https://tegonal.com/gpg/github.asc).

The following commands will do this but require you to first import our gpg key.
If you haven't done this already, then execute:

```
wget -O- https://www.tegonal.com/gpg/github.asc | gpg --import -
```

Now you are ready to execute the following commands which download and verify the public key as well as the install.sh
and of course execute the install.sh as such.


<install>

<!-- auto-generated, do not modify here but in install.sh.doc -->
```bash
currentDir=$(pwd) && \
tmpDir=$(mktemp -d -t gt-download-install-XXXXXXXXXX) && cd "$tmpDir" && \
wget "https://raw.githubusercontent.com/tegonal/gt/main/.gt/signing-key.public.asc" && \
wget "https://raw.githubusercontent.com/tegonal/gt/main/.gt/signing-key.public.asc.sig" && \
gpg --verify ./signing-key.public.asc.sig ./signing-key.public.asc && \
echo "public key trusted" && \
mkdir ./gpg && \
gpg --homedir ./gpg --import ./signing-key.public.asc && \
wget "https://raw.githubusercontent.com/tegonal/gt/v0.17.3/install.sh" && \
wget "https://raw.githubusercontent.com/tegonal/gt/v0.17.3/install.sh.sig" && \
gpg --homedir ./gpg --verify ./install.sh.sig ./install.sh && \
chmod +x ./install.sh && \
echo "verification successful" || (echo "!! verification failed, don't continue !!"; exit 1) && \
./install.sh && result=true || (echo "installation failed"; exit 1) && \
false || cd "$currentDir" && rm -r "$tmpDir" && "${result:-false}"
```

</install>

<details>
<summary>click here for an explanation of the commands</summary>

1. `mktemp ...`  
   create a temp directory so that we don't run into troubles overwriting files in your current dir
2. `wget .../signing-key.public.asc`  
   download the public key of this repo, which can be used to verify the integrity of released files.
3. `wget .../signing-key.public.asc.sig`    
   download the signature file of signing-key.public.asc
4. `gpg --verify ...`  
   verify the public key against your gpg store
5. `gpg --homedir ./gpg --import`  
   create a local gpg store and import the public key of this repository
6. `wget .../install.sh`  
   download the install.sh
7. `wget .../install.sh.sig`  
   download the signature file of install.sh
8. `gpg --homedir ./gpg --verify...`  
   verify the install.sh you downloaded is (still) valid against the public key of this repo
9. `chmod +x ./install.sh`  
   make install.sh executable
10. `echo "..."`  
	output the result of the verification
11. `./install.sh`
	execute the installation as such
12. `false || cd "$currentDir" && rm -r "$tmpDir ...`
	cleanup step: go back to where you have been before and delete the tmpDir

</details>

Per default, it downloads the latest tag and installs it into `$HOME/.local/lib/gt`
and sets up a symbolic link at `$HOME/.local/bin/gt`.

You can tweak this behaviour as shown as follows (replace the `./install.sh ...` command above):

```bash
# Download the latest tag, configure default installation directory and symbolic link
install.sh

# Download a specific tag, default installation directory and symbolic link
install.sh -t v0.3.0

# Download latest tag but custom installation directory, without the creation of a symbolic link
install.sh -d /opt/gt

# Download latest tag but custom installation directory and symlink
install.sh -d /opt/gt -ln /usr/local/bin
```

Last but not least, see [additional installation steps](#additional-installation-steps)

## manually

1. [![Download](https://img.shields.io/badge/Download-v0.17.3-%23007ec6)](https://github.com/tegonal/gt/releases/tag/v0.17.3)
2. extract the zip/tar.gz
3. open a terminal at the corresponding folder and verify the public key of this repo
   against [our public key](https://tegonal.com/gpg/github.asc):
   ```bash
   wget -O- https://tegonal.com/gpg/github.asc | gpg --import -
   gpg --verify ./signing-key.public.asc.sig ./signing-key.public.asc
   ```
4. then verify the files in ./src against the public key of this repository
   ```bash
   mkdir ./gpg
   gpg --homedir ./gpg --import ./signing-key.public.asc 
   find ./src -name "*.sig" -print0 | while read -r -d $'\0' sig; do gpg --homedir ./gpg --verify "$sig"; done && \
     echo "verification successful" || echo "verification failed, don't continue"
   rm -r ./gpg
   ```
5. copy the src directory to a place where you want to store gt:
	1. For instance, if you only want it for the current user, then place it into $HOME/.local/lib/gt
	2. if it shall be available for all users, then place it e.g. in /opt/gt or
	3. into your project directory in case you want that other contributors can use it as well without an own
	   installation
6. optional: create a symlink:
	1. only for the current user `ln -s "$HOME/.local/lib/gt/src/gt.sh" "$HOME/.local/bin/gt"`
	2. globally `ln -s "$HOME/.local/lib/gt/src/gt.sh" "/usr/local/bin/gt"`
	3. in project: `ln -s ./lib/gt/src/get.sh ./gt`
7. See [additional installation steps](#additional-installation-steps)

## additional installation steps

Typically, you add the following to your .gitignore file when fetching files via gt in your repository:

```gitignore
.gt/**/repo
.gt/**/gpg
```

Whether you commit the fetched files or not (i.e. put them on the ignore list as well) is up to you.
For instance, if you don't want to commit them and you put everything into `lib/...` (default location) then you
would add the following to your `.gitignore` in addition

```gitignore
lib/**
```

Users cloning your project or pulling the latest changes would then execute:

```bash
gt re-pull
```

to fetch all ignored files.

# Usage

Following the output of running `gt --help`:

<gt-help>

<!-- auto-generated, do not modify here but in src/gt.sh -->
```text
Commands:
pull          pull files from a previously defined remote
re-pull       re-pull files defined in pulled.tsv of a specific or all remotes
remote        manage remotes
reset         reset one or all remotes (re-establish gpg and re-pull files)
update        update pulled files to latest or particular version
self-update   update gt to the latest version

--help     prints this help
--version  prints the version of this script

INFO: Version of gt.sh is:
v0.18.0-SNAPSHOT
```

</gt-help>

## remote

Use this command to manage remotes.
Following the output of running `gt remote --help`:

<gt-remote-help>

<!-- auto-generated, do not modify here but in src/gt-remote.sh -->
```text
Commands:
add      add a remote
remove   remove a remote
list     list all remotes

--help     prints this help
--version  prints the version of this script

INFO: Version of gt-remote.sh is:
v0.18.0-SNAPSHOT
```

</gt-remote-help>

Some examples (see documentation of each sub command in subsection for more details):

<gt-remote>

<!-- auto-generated, do not modify here but in src/gt-remote.sh.doc -->
```bash
#!/usr/bin/env bash

# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

# lists all existing remotes
gt remote list

# removes the remote tegonal-scripts again
gt remote remove -r tegonal-scripts
```

</gt-remote>

## add

Following the output of running `gt remote add --help`:

<gt-remote-add-help>

<!-- auto-generated, do not modify here but in src/gt-remote.sh -->
```text
Parameters:
-r|--remote              name to refer to this the remote repository
-u|--url                 url of the remote repository
-d|--directory           (optional) directory into which files are pulled -- default: lib/<remote>
--unsecure               (optional) if set to true, the remote does not need to have GPG key(s) defined at .gt/*.asc -- default: false
-w|--working-directory   (optional) path which gt shall use as working directory -- default: .gt

--help     prints this help
--version  prints the version of this script

Examples:
# adds the remote tegonal-scripts with url https://github.com/tegonal/scripts
# uses the default location lib/tegonal-scripts for the files which will be pulled from this remote
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts

# uses a custom pull directory, files of the remote tegonal-scripts will now
# be placed into scripts/lib/tegonal-scripts instead of default location lib/tegonal-scripts
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -d scripts/lib/tegonal-scripts

# Does not complain if the remote does not provide a GPG key for verification (but still tries to fetch one)
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts --unsecure true

# uses a custom working directory
gt remote add -r tegonal-scripts -u https://github.com/tegonal/scripts -w .github/.gt

INFO: Version of gt-remote.sh is:
v0.18.0-SNAPSHOT
```

</gt-remote-add-help>

### remove

Following the output of running `gt remote remove --help`:

<gt-remote-remove-help>

<!-- auto-generated, do not modify here but in src/gt-remote.sh -->
```text
Parameters:
-r|--remote              define the name of the remote which shall be removed
-w|--working-directory   (optional) path which gt shall use as working directory -- default: .gt
--delete-pulled-files    (optional) if set, then all files defined in the remote's pulled.tsv are deleted as well

--help     prints this help
--version  prints the version of this script

Examples:
# removes the remote tegonal-scripts
gt remote remove -r tegonal-scripts

# uses a custom working directory
gt remote remove -r tegonal-scripts -w .github/.gt

INFO: Version of gt-remote.sh is:
v0.18.0-SNAPSHOT
```

</gt-remote-remove-help>

### list

Following the output of running `gt remote list --help`:

<gt-remote-list-help>

<!-- auto-generated, do not modify here but in src/gt-remote.sh -->
```text

```

</gt-remote-list-help>

## pull

Use this command to pull files from a previously defined remote (see [remote -> add](#add)).

Following the output of running `gt pull --help`:

<gt-pull-help>

<!-- auto-generated, do not modify here but in src/gt-pull.sh -->
```text
Parameters:
-r|--remote                  name of the remote repository
-t|--tag                     git tag used to pull the file/directory
-p|--path                    path in remote repository which shall be pulled (file or directory)
-d|--directory               (optional) directory into which files are pulled -- default: pull directory of this remote (defined during "remote add" and stored in .gt/<remote>/pull.args)
--chop-path                  (optional) if set to true, then files are put into the pull directory without the path specified. For files this means they are put directly into the pull directory
-w|--working-directory       (optional) path which gt shall use as working directory -- default: .gt
--auto-trust                 (optional) if set to true, all public-keys stored in .gt/remotes/<remote>/public-keys/*.asc are imported if GPG verification fails and in such a case without the need of a manual consent -- default: false
--unsecure                   (optional) if set to true, the remote does not need to have GPG key(s) defined in gpg databse or at .gt/<remote>/*.asc -- default: false
--unsecure-no-verification   (optional) if set to true, implies --unsecure true and does not verify even if gpg keys are in store or at .gt/<remote>/*.asc -- default: false

--help     prints this help
--version  prints the version of this script

Examples:
# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# pull the directory src/utility/ from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/

# pull the file .github/CODE_OF_CONDUCT.md and put it into the pull directory .github
# without repeating the path (option --chop-path), i.e is pulled directly into .github/CODE_OF_CONDUCT.md
# and not into .github/.github/CODE_OF_CONDUCT.md
gt pull -r tegonal-scripts -t v0.1.0 -d .github --chop-path true -p .github/CODE_OF_CONDUCT.md

INFO: Version of gt-pull.sh is:
v0.18.0-SNAPSHOT
```

</gt-pull-help>

Full usage example:

<gt-pull>

<!-- auto-generated, do not modify here but in src/gt-pull.sh.doc -->
```bash
#!/usr/bin/env bash

# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# pull the directory src/utility/ from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gt pull -r tegonal-scripts -t v0.1.0 -p src/utility/
```

</gt-pull>

### pull hook

gt allows to hook into the pull process at two stages:

- before the file is moved from the downloaded path to the desired location
- after the file was moved to the desired location

If you want to use those hook, then you need create a `pull-hook.sh` in `<WORKGIN_DIR>/remotes/<REMOTE>/pull-hook.sh`
(for instance in `.gt/remotes/tegonal-scripts/pull-hook.sh`).

This file should contain two functions named `gt_pullHook_<REMOTE>_before` and `gt_pullHook_<REMOTE>_after`.
<REMOTE> is the name of the remote where all `-` are replaced by `_`.
So for the remote tegonal-scripts you should name the functions `gt_pullHook_tegonal_scripts_before`
and `gt_pullHook_tegonal_scripts_after`

These two functions will be called for each file which is pulled where the following arguments are passed.

1. tag specified via `-t|--target`
2. path of the file before the move to its target destination
3. target destination

For instance, a pull-hook.sh could look as follows:

```bash
#!/usr/bin/env bash
set -eu -o pipefail

function gt_pullHook_tegonal_scripts_before(){
  # no op, nothing to do
  true
}

function gt_pullHook_tegonal_scripts_after(){
  local -r tag=$1 source=$2 target=$3
  
  if [[ $source =~ .*.txt ]]; then
    # rename all *.txt to *.msg
    mv "$target" "${target%????}.msg"
  fi  
}
```

For a real world example, take a look at the
[pull-hook.sh](https://github.com/tegonal/gt/blob/main/.gt/remotes/tegonal-gh-commons/pull-hook.sh)
used in this repo.

## re-pull

Use this command to pull missing files form all or a specific remote. You can also use it to re-pull files even if they
already exist locally.

Following the output of running `gt re-pull --help`:

<gt-re-pull-help>

<!-- auto-generated, do not modify here but in src/gt-re-pull.sh -->
```text
Parameters:
-r|--remote              (optional) if set, only the remote with this name is reset, otherwise all are reset
-w|--working-directory   (optional) path which gt shall use as working directory -- default: .gt
--auto-trust             (optional) if set to true, all public-keys stored in .gt/remotes/<remote>/public-keys/*.asc are imported if GPG verification fails and in such a case without the need of a manual consent -- default: false
--only-missing           (optional) if set, then only files which do not exist locally are pulled, otherwise all are re-pulled -- default: true

--help     prints this help
--version  prints the version of this script

Examples:
# re-pull all files of remote tegonal-scripts which are missing locally
gt re-pull -r tegonal-scripts

# re-pull all files of all remotes which are missing locally
gt re-pull

# re-pull all files (not only missing) of remote tegonal-scripts, imports gpg keys without manual consent if necessary
gt re-pull -r tegonal-scripts --only-missing false --auto-trust true

INFO: Version of gt-re-pull.sh is:
v0.18.0-SNAPSHOT
```

</gt-re-pull-help>

Full usage example:

<gt-re-pull>

<!-- auto-generated, do not modify here but in src/gt-re-pull.sh.doc -->
```bash
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
```

</gt-re-pull>

## reset

Use this command to reset one or all remotes. By resetting we mean, re-establish trust (check GPG key again) and
re-fetch all files.

Following the output of running `gt reset --help`:

<gt-reset-help>

<!-- auto-generated, do not modify here but in src/gt-reset.sh -->
```text
Parameters:
-r|--remote              (optional) if set, only the remote with this name is reset, otherwise all are reset
-w|--working-directory   (optional) path which gt shall use as working directory -- default: .gt
--gpg-only               (optional) if set, then only the gpg keys are reset but the files are not re-pulled -- default: false

--help     prints this help
--version  prints the version of this script

Examples:
# reset the remote tegonal-scripts
gt reset -r tegonal-scripts

# resets all remotes
gt reset

# resets the gpg keys of all remotes without re-pulling the corresponding files
gt reset --gpg-only true

INFO: Version of gt-reset.sh is:
v0.18.0-SNAPSHOT
```

</gt-reset-help>

Full usage example:

<gt-reset>

<!-- auto-generated, do not modify here but in src/gt-reset.sh.doc -->
```bash
#!/usr/bin/env bash

# resets all defined remotes, which means for each remote in .gt
# - re-initialise gpg trust based on public keys defined in .gt/remotes/<remote>/public-keys/*.asc
# - pull files defined in .gt/remotes/<remote>/pulled.tsv
gt reset

# resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .gt/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .gt/remotes/tegonal-scripts/pulled.tsv
gt reset -r tegonal-scripts

# uses a custom working directory and resets the remote tegonal-scripts which means:
# - re-initialise gpg trust based on public keys defined in .github/.gt/remotes/tegonal-scripts/public-keys/*.asc
# - pull files defined in .github/.gt/remotes/tegonal-scripts/pulled.tsv
gt reset -r tegonal-scripts -w .github/.gt
```

</gt-reset>

## Update

Use this command to update already pulled files.
Following the output of running `gt update --help`:

<gt-update-help>

<!-- auto-generated, do not modify here but in src/gt-update.sh -->
```text
Parameters:
-r|--remote              (optional) if set, only the files of this remote are updated, otherwise all
-w|--working-directory   (optional) path which gt shall use as working directory -- default: .gt
--auto-trust             (optional) if set to true, all public-keys stored in .gt/remotes/<remote>/public-keys/*.asc are imported if GPG verification fails and in such a case without the need of a manual consent -- default: false
-t|--tag                 (optional) define from which tag files shall be pulled, only valid if remote via -r|--remote is specified

--help     prints this help
--version  prints the version of this script

Examples:
# updates all pulled files of all remotes to latest tag
gt update

# updates all pulled files of remote tegonal-scripts to latest tag
gt update -r tegonal-scripts

# updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
gt update -r tegonal-scripts -t v1.0.0

INFO: Version of gt-update.sh is:
v0.18.0-SNAPSHOT
```

</gt-update-help>

Full usage example:

<gt-update>

<!-- auto-generated, do not modify here but in src/gt-update.sh.doc -->
```bash
#!/usr/bin/env bash

# updates all pulled files of all remotes to latest tag
gt update

# updates all pulled files of remote tegonal-scripts to latest tag
gt update -r tegonal-scripts

# updates/downgrades all pulled files of remote tegonal-scripts to tag v1.0.0
gt update -r tegonal-scripts -t v1.0.0
```

</gt-update>

### GitHub Workflow

This repository contains a github workflow which runs every week to check if there are updates for:

- the files which have been pulled as well as
- the public keys of the remotes.

It requires you to define a variable named PUBLIC_GPG_KEYS_WE_TRUST which represents an armored export of all
gpg public keys you trust signing the public keys of remotes, 
i.e. those are used to verify the public keys of the remotes you added via `gt remote add`.

You can define two optional secrets in addition which steer the PR creation which is done via the github action
[peter-evans/create-pull-request](https://github.com/peter-evans/create-pull-request):
- `AUTO_PR_TOKEN` is used as `token`
- `AUTO_PR_FORK_NAME` is used as `push-to-fork` (we look first for a variable `AUTO_PR_FORK_NAME` and fallback to a secret afterwards)

You can re-use the workflow in your repository. We suggest you fetch it via gt 😉

```bash
gt remote add -r gt -u https://github.com/tegonal/gt
gt pull -r gt -p .github/workflows/gt-update.yml -d ./ 
```

Accordingly, you would add [Tegonal's public key for github](https://tegonal.com/gpg/github.asc) to PUBLIC_GPG_KEYS_WE_TRUST in order
that this workflow can update the workflow itself.

#### Required modifications

You need to change one condition in the workflow which we added in order that this workflow does not run in forks:

```yml
if: github.repository_owner == 'tegonal'
```

Which means you should rewrite that part it in the [pull-hook.sh](#pull-hook) of the gt remote, i.e.
in `.gt/remotes/gt/pull-hook.sh`. It could look as follows:

```bash
set -eu -o pipefail

function gt_pullHook_gt_before(){
  local -r _tag=$1 source=$2 _target=$3
  
  if [[ $source =~ .*/.github/workflows/gt-update.yml ]]; then
    perl -0777 -i -pe "s/(if: github.repository_owner == )'tegonal'/\${1}'YOUR_SLUG'/" "$source"
  fi  
}

function gt_pullHook_gt_after(){
  # no op, nothing to do
  true
}
```

Just make sure you replace YOUR_SLUG with your actual slug.

### Gitlab Job

The setup requires three steps:
1. pull files and include in your .gitlab-ci.yml
2. configure Variables and Deploy Keys
3. Set up a Scheduled Pipeline

#### setup .gitlab-ci.yml

This repository contains a `.gitlab-ci.yml` which defines two job templates:
1. gt-update which checks if there are updates for:
   - the files which have been pulled
   - the public keys of the remotes

   and creates a Merge Request if there are some.

2. gt-update-stop-pipeline which cancels itself and thus stops the pipeline

You can re-use it in your repository. We suggest you fetch it via gt 😉

```bash
gt remote add -r gt -u https://github.com/tegonal/gt
gt pull -r gt -p src/gitlab/
```

In your `.gitlab-ci.yml` you need to add `gt` to your stages and it should be the first stage:
```yml
stages:
- gt
...
```
At some point you add in addition
```yml
include: 'lib/gt/src/gitlab/.gitlab-ci.yml'
```

That's it, this defines the two jobs. Yet, you need some extra configuration to be ready to use it...

<details>
<summary>I need some modifications to the standard job</summary>

If you need to run additional before_script or the like, then you can re-define
the job e.g. as follows (after the `include` above):
```yaml
gt-update:
  extends: .gt-update
  # your modifications here, e.g. for an additional step in before_script
  before_script:
	- !reference [.gt-update, before_script]
    - cd subdirectory
```

</details>

#### Additional configuration

The `gt-update` job (the `install-gt.sh` to be precise) 
requires you to define a variable named PUBLIC_GPG_KEYS_WE_TRUST which represents an armored export of all
gpg public keys you trust signing the public keys of remotes, 
i.e. those are used to verify the public keys of the remotes you added via `gt remote add`.

For instance, if you fetched the gitlab job via gt as suggested, 
then you would add [Tegonal's public key for github](https://tegonal.com/gpg/github.asc) 
to PUBLIC_GPG_KEYS_WE_TRUST in order that this job can update itself.

Moreover, the `create-mr.sh` requires an access token which is stored in variable GT_UPDATE_API_TOKEN. 
It is used to create the merge request.

The gitlab job uses the image [gitlab-git](https://github.com/tegonal/gitlab-git) which requires you to define 
the variable GITBOT_SSH_PRIVATE_KEY and a deploy key for it. 
See [Basic Setup](https://github.com/tegonal/gitlab-git#basic-setup) for more information

#### Scheduled job

Now, all that is left is to create a scheduled pipeline (CI/CD -> Schedules) where you need to define Variable 
`DO_GT_UPDATE` with value `true`. Up to you how often you want to let it run (we run it weekly).

## self-update

You can update gt by using gt (which in turn uses its install.sh)
Following the output of running `gt self-update --help`:

<gt-self-update-help>

<!-- auto-generated, do not modify here but in src/gt-self-update.sh -->
```text
Parameters:
--force   if set to true, then install.sh will be called even if gt is already on latest tag

--help     prints this help
--version  prints the version of this script

Examples:
# updates gt to the latest tag
gt self-update

# updates gt to the latest tag and downloads the sources even if already on the latest
gt self-update --force

INFO: Version of gt-self-update.sh is:
v0.18.0-SNAPSHOT
```

</gt-self-update-help>

# FAQ

## 1. How is gt different from git submodules?

Short version:

- git (v2.73.3) submodules only support to checkout a certain branch but not a certain tag.
- gt only supports to pull files from a certain tag but not from a random branch or sha

Longer version:

- gt also integrates file integrity checks based on GPG
- allows to fetch only parts of a repository (maybe possible for submodules via sparse checkout)
- allows to place it at different places
- is not intended to push changes back

# Does gt run on all linux distros?

Most likely not, it was tested only on Ubuntu 22.04.  
For instance, on alpine you need to `apk add bash git gnupg perl coreutils` to make `gt update` work 
(could be that executing other gt commands require more dependencies).

# Contributors and contribute

Our thanks go to [code contributors](https://github.com/tegonal/gt/graphs/contributors)
as well as all other contributors (e.g. bug reporters, feature request creators etc.)

You are more than welcome to contribute as well:

- star this repository if you like/use it
- [open a bug](https://github.com/tegonal/gt/issues/new?template=bug_report.md) if you find one
- Open a [new discussion](https://github.com/tegonal/gt/discussions/new?category=ideas) if you are missing a feature
- [ask a question](https://github.com/tegonal/gt/discussions/new?category=q-a)
  so that we better understand where our scripts need to improve.
- have a look at
  the [help wanted issues](https://github.com/tegonal/gt/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
  if you would like to code.

Please have a look at
[CONTRIBUTING.md](https://github.com/tegonal/gt/tree/main/.github/CONTRIBUTING.md)
for further suggestions and guidelines.

# License

gt is licensed under [European Union Public Licence v. 1.2](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12).

gt is using:
- [tegonal scripts](https://github.com/tegonal/scripts) licensed under [Apache 2.0](https://opensource.org/licenses/Apache2.0)
