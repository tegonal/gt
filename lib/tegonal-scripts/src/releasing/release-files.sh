#!/usr/bin/env bash
#
#    __                          __
#   / /____ ___ ____  ___  ___ _/ /       This script is provided to you by https://github.com/tegonal/scripts
#  / __/ -_) _ `/ _ \/ _ \/ _ `/ /        It is licensed under Apache 2.0
#  \__/\__/\_, /\___/_//_/\_,_/_/         Please report bugs and contribute back your improvements
#         /___/
#                                         Version: v0.10.0
#
#######  Description  #############
#
#  Releasing files based on conventions:
#  - expects a version in format vX.Y.Z(-RC...)
#  - main is your default branch
#  - requires you to have a /scripts folder in your project root which contains:
#    - before-pr.sh which provides a parameterless function beforePr and can be sourced (add ${__SOURCED__:+return} before executing beforePr)
#    - prepare-next-dev-cycle.sh which provides function prepareNextDevCycle and can be sourced
#  - there is a public key defined at .gget/signing-key.public.asc which will be used
#    to verify the signatures which will be created
#
#  You can define /scripts/additional-release-files-preparations.sh which is sourced (via sourceOnce) if it exists.
#
#######  Usage  ###################
#
#    #!/usr/bin/env bash
#    set -euo pipefail
#    # Assumes tegonal's scripts were fetched with gget - adjust location accordingly
#    dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/../lib/tegonal-scripts/src")"
#    source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
#
#    function findScripts() {
#    	find "src" -name "*.sh" -not -name "*.doc.sh" "$@"
#    }
#    # make the function visible to release-files.sh / not necessary if you source release-files.sh, see further below
#    declare -fx findScripts
#
#    # releases version v0.1.0 using the key 0x945FE615904E5C85 for signing
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" -v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts
#
#    # releases version v0.1.0 using the key 0x945FE615904E5C85 for signing and
#    # searches for additional occurrences where the version should be replaced via the specified pattern in:
#    # - script files in ./src and ./scripts
#    # - ./README.md
#    "$dir_of_tegonal_scripts/releasing/release-files.sh" \
#    	-v v0.1.0 -k "0x945FE615904E5C85" --sign-fn findScripts \
#    	-p "(TEGONAL_SCRIPTS_VERSION=['\"])[^'\"]+(['\"])"
#
#    # in case you want to provide your own release.sh and only want to do some pre-configuration
#    # then you might want to source it instead
#    sourceOnce "$dir_of_tegonal_scripts/releasing/release-files.sh"
#
#    # and then call the function with your pre-configuration settings:
#    # here we define the function which shall be used to find the files to be signed
#    # since "$@" follows afterwards, one could still override it via command line arguments.
#    # put "$@" first, if you don't want that a user can override your pre-configuration
#    releaseFiles --sign-fn findScripts "$@"
#
###################################
set -euo pipefail
export TEGONAL_SCRIPTS_VERSION='v0.10.0'

if ! [[ -v dir_of_tegonal_scripts ]]; then
	dir_of_tegonal_scripts="$(realpath "$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)/..")"
	source "$dir_of_tegonal_scripts/setup.sh" "$dir_of_tegonal_scripts"
fi
sourceOnce "$dir_of_tegonal_scripts/utility/git-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/gpg-utils.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/ask.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/log.sh"
sourceOnce "$dir_of_tegonal_scripts/utility/parse-args.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/sneak-peek-banner.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/toggle-sections.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-README.sh"
sourceOnce "$dir_of_tegonal_scripts/releasing/update-version-scripts.sh"

function releaseFiles() {
	local version key findForSigning projectDir additionalPattern nextVersion prepareOnly
	# shellcheck disable=SC2034
	local -ra params=(
		version '-v' "The version to release in the format vX.Y.Z(-RC...)"
		key '-k|--key' 'The GPG private key which shall be used to sign the files'
		findForSigning '--sign-fn' 'Function which is called to determine what files should be signed. It should be based find and allow to pass further arguments (we will i.a. pass -print0)'
		projectDir '--project-dir' '(optional) The projects directory -- default: .'
		additionalPattern '-p|--pattern' '(optional) pattern which is used in a perl command (separator /) to search & replace additional occurrences. It should define two match groups and the replace operation looks as follows: '"\\\${1}\$version\\\${2}"
		nextVersion '-nv|--next-version' '(optional) the version to use for prepare-next-dev-cycle -- default: is next minor based on version'
		prepareOnly '--prepare-only' '(optional) defines whether the release shall only be prepared (i.e. no push, no tag, no prepare-next-dev-cycle) -- default: false'
	)

	parseArguments params "" "$TEGONAL_SCRIPTS_VERSION" "$@"

	local -r versionRegex="^(v[0-9]+)\.([0-9]+)\.[0-9]+(-RC[0-9]+)?$"

	if [[ -v version ]]; then
		if ! [[ -v nextVersion ]] && [[ "$version" =~ $versionRegex ]]; then
			nextVersion="${BASH_REMATCH[1]}.$((BASH_REMATCH[2] + 1)).0"
		else
			logInfo "cannot deduce nextVersion from version as it does not follow format vX.Y.Z(-RC...): $version"
		fi
	fi
	if ! [[ -v projectDir ]]; then projectDir=$(realpath "."); fi
	if ! [[ -v additionalPattern ]]; then additionalPattern="^$"; fi
	if ! [[ -v prepareOnly ]] || ! [[ "$prepareOnly" == "true" ]]; then prepareOnly=false; fi
	checkAllArgumentsSet params "" "$TEGONAL_SCRIPTS_VERSION"

	if ! [[ "$version" =~ $versionRegex ]]; then
		returnDying "--version should match vX.Y.Z(-RC...), was %s" "$version"
	fi

	if hasGitChanges; then
		logError "you have uncommitted changes, please commit/stash first, following the output of git status:"
		git status
		return 1
	fi

	if git tag | grep "$version" >/dev/null; then
		logError "tag %s already exists locally, adjust version or delete it with git tag -d %s" "$version" "$version"
		if hasRemoteTag "$version"; then
			printf >&2 "Note, it also exists on the remote which means you also need to delete it there -- e.g. via git push origin :%s\n" "$version"
			return 1
		fi
		logInfo "looks like the tag only exists locally."
		if askYesOrNo "Shall I \`git tag -d %s\` and continue with the release?" "$version"; then
			git tag -d "$version"
		else
			return 1
		fi
	fi

	if hasRemoteTag "$version"; then
		returnDying "tag %s already exists on remote origin, adjust version or delete it with git push origin :%s\n" "$version" "$version"
	fi

	local -r branch="$(currentGitBranch)"
	local -r expectedDefaultBranch="main"
	if ! [[ $branch == "$expectedDefaultBranch" ]]; then
		logError "you need to be on the \033[0;36m%s\033[0m branch to release, check that you have merged all changes from your current branch \033[0;36m%s\033[0m." "$expectedDefaultBranch" "$branch"
		if askYesOrNo "Shall I switch to %s for you?" "$expectedDefaultBranch"; then
			git checkout "$expectedDefaultBranch"
		else
			return 1
		fi
	fi

	if localGitIsAhead "$expectedDefaultBranch"; then
		logError "you are ahead of origin, please push first and check if CI succeeds before releasing. Following your additional changes:"
		git -P log origin/main..main
		if askYesOrNo "Shall I git push for you?"; then
			git push
			logInfo "please check if your push passes CI and re-execute the release command afterwards"
		fi
		return 1
	fi

	if localGitIsBehind "$expectedDefaultBranch"; then
		git fetch
		logError "you are behind of origin. I already fetched the changes for you, please check if you still want to release. Following the additional changes in origin/main:"
		git -P log "${expectedDefaultBranch}..origin/$expectedDefaultBranch"
		if askYesOrNo "Do you want to git pull?"; then
			git pull
			if ! askYesOrNo "Do you want to release now?"; then
				return 1
			fi
		else
			return 1
		fi
	fi

	local -r projectsScriptsDir="$projectDir/scripts"
	sourceOnce "$projectsScriptsDir/before-pr.sh"

	# make sure everything is up-to-date and works as it should
	beforePr

	sneakPeekBanner -c hide
	toggleSections -c release
	updateVersionReadme -v "$version" -p "$additionalPattern"
	updateVersionScripts -v "$version" -p "$additionalPattern"
	updateVersionScripts -v "$version" -p "$additionalPattern" -d "$projectsScriptsDir"
	local -r additionalSteps="$projectsScriptsDir/additional-release-files-preparations.sh"
	if [[ -f $additionalSteps ]]; then
		sourceOnce "$additionalSteps"
	fi

	# run again since we made changes
	beforePr

	local -r ggetDir="$projectDir/.gget"
	local -r gpgDir="$ggetDir/gpg"
	rm -rf "$gpgDir"
	mkdir "$gpgDir"
	chmod 700 "$gpgDir"

	gpg --homedir "$gpgDir" --import "$ggetDir/signing-key.public.asc"
	trustGpgKey "$gpgDir" "info@tegonal.com"

	"$findForSigning" -print0 |
		while read -r -d $'\0' script; do
			echo "signing $script"
			gpg --detach-sign --batch --yes -u "$key" -o "${script}.sig" "$script"
			gpg --homedir "$gpgDir" --batch --verify "${script}.sig" "$script"
		done

	if ! [[ $prepareOnly == true ]]; then
		git add .
		git commit -m "$version"
		git tag "$version"

		sourceOnce "$projectsScriptsDir/prepare-next-dev-cycle.sh"
		prepareNextDevCycle -v "$nextVersion" -p "$additionalPattern"

		git push origin "$version"
		git push
	else
		printf "\033[1;33mskipping commit, creating tag and prepare-next-dev-cylce due to --prepare-only\033[0m\n"
	fi
}

${__SOURCED__:+return}
releaseFiles "$@"
