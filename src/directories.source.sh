#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2168,SC2154

local -r remotesDirectory="$workingDirectory/remotes"
local -r remoteDirectory="$remotesDirectory/$remote"
local -r publicKeys="$remoteDirectory/public-keys"
local -r repo="$remoteDirectory/repo"
local -r gpgDir="$publicKeys/gpg"
