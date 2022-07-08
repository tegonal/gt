<!-- for main -->

[![Download](https://img.shields.io/badge/Download-v0.1.0-%23007ec6)](https://github.com/tegonal/gget/releases/tag/v0.1.0)
[![Apache 2.0](https://img.shields.io/badge/%E2%9A%96-Apache%202.0-%230b45a6)](http://opensource.org/licenses/Apache2.0 "License")
[![Code Quality](https://github.com/tegonal/gget/workflows/Code%20Quality/badge.svg?event=push&branch=main)](https://github.com/tegonal/gget/actions/workflows/code-quality.yml?query=branch%3Amain)
[![Newcomers Welcome](https://img.shields.io/badge/%F0%9F%91%8B-Newcomers%20Welcome-blueviolet)](https://github.com/tegonal/gget/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22 "Ask in discussions for help")

<!-- for main end -->
<!-- for a specific release -->
<!--
[![Download](https://img.shields.io/badge/Download-v0.1.0-%23007ec6)](https://github.com/tegonal/gget/releases/tag/v0.1.0)
[![Apache 2.0](https://img.shields.io/badge/%E2%9A%96-Apache%202.0-%230b45a6)](http://opensource.org/licenses/Apache2.0 "License")
[![Newcomers Welcome](https://img.shields.io/badge/%F0%9F%91%8B-Newcomers%20Welcome-blueviolet)](https://github.com/tegonal/gget/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22 "Ask in discussions for help")
-->
<!-- for a specific release end -->
# gget

g(it)get is a bash based script which fetches a file or a directory stored in a git repository including automatic verification via GPG signature.

**The initial idea behind this project**:  
You have scripts you use in multiple projects and would like to have a single place where you maintain them.
Maybe you even made them public so that others can use them as well (as we have done with [Tegonal scripts](https://github.com/tegonal/gget)).
This tool provides an easy way to fetch them into your project. 

---

❗ You are taking a _sneak peek_ at the next version.
Please have a look at the README of the git tag in case you are looking for the documentation of the corresponding version.
For instance, the [README of v0.1.0](https://github.com/tegonal/gget/tree/v0.1.0/README.md).

---

**Table of Content**
- [Installation](#installation)
- [Usage](#usage)
  - [remote](#remote)
    - [add](#add)
    - [remove](#remove)
    - [list](#list)
  - [pull](#pull) 
- [Contributors and contribute](#contributors-and-contribute)
- [License](#license)

# Installation

1. [![Download](https://img.shields.io/badge/Download-v0.1.0-%23007ec6)](https://github.com/tegonal/gget/releases/tag/v0.1.0)
2. extract the zip/tar.gz
3. copy the src directory to a place where you want to store gget e.g. /opt/gget or into your project directory
4. optional: create a symlink `ln -s /opt/gget/gget.sh /usr/local/bin/gget`

# Usage

Following the output of running `gget --help`:

<gget-help>

<!-- auto-generated, do not modify here but in src/gget.sh -->
```text
Use one of the following commands:
pull     pull files from a remote
remote   manage remotes
```

</gget-help>

## remote

Following the output of running `gget remote --help`:

<gget-remote-help>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```text
Use one of the following commands:
add      add a remote
remove   remove a remote
list     list all existing remotes
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
-r|--remote              define the name of the remote repository to use
-u|--url                 define the url of the remote repository
-d|--directory           (optional) define into which directory files of this remote will be pulled -- default: lib/<remote>
--unsecure               (optional) if set to true, the remote does not need to have GPG key(s) defined at .gget/*.asc -- default: false
-w|--working-directory   (optional) define a path which gget shall use as working directory -- default: .gget

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
```

</gget-remote-add-help>

### remove

Following the output of running `gget remote remove --help`:

<gget-remote-remove-help>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```text
Parameters:
-r|--remote              define the name of the remote which shall be removed
-w|--working-directory   (optional) define a path which gget shall use as working directory -- default: .gget

Examples:
# removes the remote tegonal-scripts
gget remote remove -r tegonal-scripts

# uses a custom working directory
gget remote remove -r tegonal-scripts -w .github/.gget
```

</gget-remote-remove-help>

### list

Following the output of running `gget remote list --help`:

<gget-remote-list-help>

<!-- auto-generated, do not modify here but in src/gget-remote.sh -->
```text
Parameters:
-w|--working-directory   (optional) define a path which gget shall use as working directory -- default: .gget

Examples:
# lists all defined remotes in .gget
gget remote list

# uses a custom working directory
gget remote list -w .github/.gget
```

</gget-remote-list-help>

## pull

Following the output of running `gget pull --help`:

<gget-pull-help>

<!-- auto-generated, do not modify here but in src/gget-pull.sh -->
```text
Parameters:
-r|--remote                  define the name of the remote repository to use
-t|--tag                     define which tag should be used to pull the file/directory
-p|--path                    define which file or directory shall be fetched
-d|--directory               (optional) define into which directory files of this remote will be pulled -- default: pull directory of this remote (defined during "remote add" and stored in .gget/<remote>/pull.args)
-w|--working-directory       (optional) define arg path which gget shall use as working directory -- default: .gget
--unsecure                   (optional) if set to true, the remote does not need to have GPG key(s) defined at .gget/<remote>/*.asc -- default: false
--unsecure-no-verification   (optional) if set to true, implies --unsecure true and does not verify even if gpg keys were found at .gget/<remote>/*.asc -- default: false

Examples:
# pull the file src/utility/update-bash-docu.sh from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/update-bash-docu.sh

# pull the directory src/utility/ from remote tegonal-scripts
# in version v0.1.0 (i.e. tag v0.1.0 is used)
gget pull -r tegonal-scripts -t v0.1.0 -p src/utility/
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
