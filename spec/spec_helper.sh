# shellcheck shell=sh
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#
#

# Defining variables and functions here will affect all specfiles.
# Change shell options inside a function may cause different behavior,
# so it is better to set them here.
# set -euo pipefail

# This callback function will be invoked only once before loading specfiles.
spec_helper_precheck() {
	# Available functions: info, warn, error, abort, setenv, unsetenv
	# Available variables: VERSION, SHELL_TYPE, SHELL_VERSION
	: minimum_version "0.28.1"
}

# This callback function will be invoked after a specfile has been loaded.
spec_helper_loaded() {
	:
}

# This callback function will be invoked after core modules has been loaded.
spec_helper_configure() {
	# Available functions: import, before_each, after_each, before_all, after_all
	: import 'test-utils/custom_matcher'
}
