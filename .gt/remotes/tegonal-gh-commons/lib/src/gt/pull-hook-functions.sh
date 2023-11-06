#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/github-commons
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Creative Commons Zero v1.0 Universal
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v1.1.0
#
#######  Description  #############
#
#  functions which can be used to update the placeholders in the templates in a gt pull-hook.sh
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    shopt -s inherit_errexit
#    MY_PROJECT_LATEST_VERSION="v1.0.0"
#
#    # Assumes tegonal's github-commons was fetched with gt and put into repoRoot/.gt/remotes/tegonal-gh-commons/lib
#    # - adjust remote name or location accordingly
#    dir_of_github_commons="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/lib/src"
#
#    if ! [[ -v dir_of_tegonal_scripts ]]; then
#    	dir_of_tegonal_scripts="$dir_of_github_commons/../tegonal-scripts/src"
#    	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#    fi
#
#    source "$dir_of_github_commons/gt/pull-hook-functions.sh"
#
#    declare _tag=$1 source=$2 _target=$3
#    shift 3 || die "could not shift by 3"
#
#    replacePlaceholdersCodeOfConduct "$source" "code-of-conduct@my-company.com"
#    replacePlaceholdersContributorsAgreement "$source" "my-project-name" "MyCompanyName, Country"
#    replacePlaceholdersPullRequestTemplate "$source" "https://github.com/tegonal/my-project-name" "$MY_PROJECT_LATEST_VERSION"
#
#    # also have a look at https://github.com/tegonal/gt/blob/main/.gt/remotes/tegonal-scripts/pull-hook.sh
#
###################################
set -euo pipefail
shopt -s inherit_errexit
unset CDPATH

if ! [[ -v dir_of_github_commons ]]; then
	dir_of_github_commons="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null && pwd 2>/dev/null)/.."
	readonly dir_of_github_commons
fi

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$dir_of_github_commons/../tegonal-scripts/src"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi

function replacePlaceholdersContributorsAgreement() {
	if ! (($# == 3)); then
		logError "you need to pass three arguments to replacePlaceholdersContributorsAgreement"
		echo "1: file         represents the 'Contributor Agreement.txt'"
		echo "2: projectName  the name of the project"
		echo "3: owner				owner of the project"
		printStackTrace
		exit 9
	fi
	local -r file=$1
	local -r projectName=$2
	local -r owner=$3
	shift 3 || die "could not shift by 3"
	PROJECT_NAME="$projectName" OWNER="$owner" perl -0777 -i \
		-pe 's/<PROJECT_NAME>/$ENV{PROJECT_NAME}/g;' \
		-pe 's/<OWNER>/$ENV{OWNER}/g;' \
		"$file"
}

function replacePlaceholdersContributorsAgreement_Tegonal() {
	if ! (($# == 2)); then
		logError "you need to pass two arguments to replacePlaceholdersContributorsAgreement_Tegonal"
		echo "1: file         represents the 'Contributor Agreement.txt'"
		echo "2: projectName  the name of the project"
		printStackTrace
		exit 9
	fi
	local -r file=$1
	local -r projectName=$2
	shift 2 || die "could not shift by 2"
	replacePlaceholdersContributorsAgreement "$file" "$projectName" "Tegonal Genossenschaft, Switzerland"
}

function replacePlaceholdersPullRequestTemplate() {
	if ! (($# == 3)); then
		logError "you need to pass three arguments to replacePlaceholdersPullRequestTemplate"
		echo "1: file        represents the 'PULL_REQUEST_TEMPLATE.md'"
		echo "2: url				 the github url"
		echo "3: latestTag   latest tag"
		printStackTrace
		exit 9
	fi
	local -r file=$1
	local -r url=$2
	local -r tag=$3
	shift 3 || die "could not shift by 3"
	TAG="$tag" GITHUB_URL="$url" perl -0777 -i \
		-pe 's#<GITHUB_URL>#$ENV{GITHUB_URL}#g;' \
		-pe 's#<TAG>#$ENV{TAG}#g;' \
		"$file"
}

function replacePlaceholdersCodeOfConduct(){
	if ! (($# == 2)); then
		logError "you need to pass two arguments to replacePlaceholdersCodeOfConductTemplate"
		echo "1: file         represents the 'CODE_OF_CONDUCT.md'"
		echo "2: owner_email	email address which should be contacted in case of a violation"
		printStackTrace
		exit 9
	fi
	local -r file=$1
	local -r ownerEmail=$2
	shift 2 || die "could not shift by 2"
	EMAIL="$ownerEmail" perl -0777 -i \
		-pe 's/<OWNER_EMAIL>/$ENV{EMAIL}/g;' \
		"$file"
}

function replacePlaceholdersCodeOfConduct_Tegonal(){
	if ! (($# == 1)); then
		logError "you need to pass one arguments to replacePlaceholdersCodeOfConductTemplate"
		echo "1: file         represents the 'CODE_OF_CONDUCT.md'"
		printStackTrace
		exit 9
	fi
	local -r file=$1
	shift 1 || die "could not shift by 1"
	replacePlaceholdersCodeOfConduct "$file" "info@tegonal.com"
}

function replaceTagInPullRequestTemplate() {
	if ! (($# == 3)); then
		logError "you need to pass three arguments to replaceTagInPullRequestTemplate"
		echo "1: file   represents the 'PULL_REQUEST_TEMPLATE.md'"
		echo "2: url	  the github url"
		echo "3: tag    tag to set in url"
		printStackTrace
		exit 9
	fi
	local -r file=$1
	local -r url=$2
	local -r tag=$3
	shift 3 || die "could not shift by 3"

	perl -0777 -i \
		-pe "s#($url/blob/)[^/]+/#\${1}$tag/#;" \
		"$file"
}
