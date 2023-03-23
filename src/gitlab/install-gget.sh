#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/gget
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache License 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.10.0-SNAPSHOT
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH
if ! [[ -v dir_of_gget_gitlab ]]; then
	dir_of_gget_gitlab="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)"
	readonly dir_of_gget_gitlab
fi
source "$dir_of_gget_gitlab/utils.sh"

# shellcheck disable=SC2034   # is passed to exitIfEnvVarNotSet by name
declare -a envVars=(
	PUBLIC_GPG_KEYS_WE_TRUST
)
exitIfEnvVarNotSet envVars
readonly PUBLIC_GPG_KEYS_WE_TRUST

# shellcheck disable=SC2034   # is passed to cleanupTmp by name
readonly -a tmpPaths=(tmpDir)
trap 'cleanupTmp tmpPaths' EXIT

gpg --import - <<<"$PUBLIC_GPG_KEYS_WE_TRUST"

# see install.doc.sh in https://github.com/tegonal/gget, MODIFY THERE NOT HERE (please report bugs)
currentDir=$(pwd) && \
tmpDir=$(mktemp -d -t gget-download-install-XXXXXXXXXX) && cd "$tmpDir" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/.gget/signing-key.public.asc" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/.gget/signing-key.public.asc.sig" && \
gpg --verify ./signing-key.public.asc.sig ./signing-key.public.asc && \
echo "public key trusted" && \
mkdir ./gpg && \
gpg --homedir ./gpg --import ./signing-key.public.asc && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh.sig" && \
gpg --homedir ./gpg --verify ./install.sh.sig ./install.sh && \
chmod +x ./install.sh && \
echo "verification successful" || (echo "verification failed, don't continue"; exit 1) && \
./install.sh && result=true || (echo "installation failed"; exit 1) && \
false || cd "$currentDir" && rm -r "$tmpDir" && "${result:-false}"
# end install.doc.sh
