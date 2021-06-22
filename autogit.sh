#!/usr/bin/env bash
# Git automatic administration script

# MIT License

# Copyright (c) 2020 Tristan Landes

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#########################################################
#      Initialization and config default values
#########################################################

# Resolve current directory path. Code from https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself/246128#246128
# Resolve $SOURCE until the file is no longer a symlink
# If $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do HERE="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"; SOURCE="$(readlink "$SOURCE")"; [[ $SOURCE != /* ]] && SOURCE="$HERE/$SOURCE"; done
HERE="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Setting bash strict mode. See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t,'

# Script version
version='1.5'

# SCRIPT CONFIG: Configurable with options -r <> [-k <>] [-c <>] [-a] [-m <>] [-f <>] [-q] [-o] [-x <>]
# You can set default values here
# Repositories: Default repositorie(s). Option  -r <>
# Exemple: repositories=("~/autogit/","~/wpscan/")
repositories=()
# SSH key. Option [-k <>]
# Exemple: ssh_key="~/.ssh/github"
ssh_key=""
# URL of the git source. Option [-c <>]
git_clone_url=""
# First commit messages. Option [-m <>] 
commit_msg_text=""
# Will read second message from file. Option [-f <>] 
commit_msg_from_file=""
# Add untracked files to git: true(0)/false(1). Option [-a]
git_add_untracked=1
# Quiet: Option [-q]
is_quiet=1
# Read only: If set to true equivalent to (repository) read-only: no commit or push changes. [-o]
# Will still pull and merge remote changes into working copy!
read_only=1
# Git remote [-x <>]
git_remote=origin

# SCRIPT VARIABLES
# See help '-h' for more informations
optstring="hqnok:x:c:m:f:ar:b:t:u:i:s:"
# Dertermine hostname
host="Unknown"
if [[ -e "/etc/hostname" ]]; then
    host=$(cat /etc/hostname)
else
    if which hostname > /dev/null; then
        host=$(hostname)
    fi
fi

init_folder=$(pwd)
date_time_str=$(date +"%Y-%m-%dT%H-%M-%S")
commit_and_stash_name="[autogit] Changes on ${host} ${date_time_str}"

#########################################################
#                    Functions
#########################################################
download_docs_if_not_found(){
    if ! [[ -e "$HERE/readme.md" ]]; then
        cd "$HERE"
        echo "Downloading docs from the internet..."
        curl --silent https://raw.githubusercontent.com/tristanlatr/autogit/master/readme.md > "$HERE/readme.md"
        cd "$init_folder"
    fi
}
quick_usage(){
    download_docs_if_not_found
    grep "Usage summary" "$HERE/readme.md"
}
usage(){
    download_docs_if_not_found
    cat "$HERE/readme.md"
}

# Usage: git_command git command
git_command(){
    # echo "[DEBUG] git_command params: $@"
    # Need to reset the IFS temporarly to space because encapsulating git command in ssh-agent
    # Seems not to work with regular "$@" ...
    if [[ -n "${ssh_key}" ]] ; then
        IFS=' '
        if ! ssh-agent bash -c "ssh-add ${ssh_key} 2>&1 && $*"; then
            >&2 echo "[WARNING] Retrying in a bit. Failed command: $*"
            sleep $(( ( RANDOM % 10 ) +1 ))
            if ! ssh-agent bash -c "ssh-add ${ssh_key} 2>&1 && $*"; then
                >&2 echo "[ERROR] Fatal error. Failed command: $*"
                return 1
            fi
        fi
        IFS=$'\n\t,'
    else
        if ! "$@"; then
            >&2 echo "[WARNING] Retrying in a bit. Failed command:" "$@"
            sleep $(( ( RANDOM % 10 ) +1 ))
            if ! "$@"; then
                >&2 echo "[ERROR] Fatal error. Failed command:" "$@"
                return 1
            fi
        fi
    fi
    return 0
}
# Usage : if is_changes_in_tracked_files; then ...
is_changes_in_tracked_files(){
    if ! git diff-files --quiet -- || ! git diff-index --quiet --cached --exit-code HEAD
    then
        return 0
    else
        return 1
    fi
}
# Usage: commit_local_changes
commit_local_changes(){
    echo "[INFO] Committing changes"
    git add -u
    echo -e "${commit_msg_text}\n" "${commit_msg_from_file}\n" "${commit_and_stash_name}" > /tmp/commit-msg.txt
    git commit -F /tmp/commit-msg.txt

}

#########################################################
#                    Syntax check
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        h) ;;
        q) ;;
        k) ;;
        x) ;;
        c) ;;
        m) ;;
        f) ;;
        a) ;;
        r) ;;
        b) ;;
        t) ;;
        u) ;;
        i) ;;
        s) ;;
        o) ;;
        *)
            quick_usage
            >&2 echo "[ERROR] You made a syntax mistake calling the script. Please see '$0 -h' for more infos." 
            exit 3
    esac
done
OPTIND=1

#########################################################
#                    Quiet mode : -q
#########################################################
# Saves stdout, Restore stdout: `exec 1>&6 6>&- `
exec 6>&1 
while getopts "${optstring}" arg; do
    case "${arg}" in
        q)
            is_quiet=0
            ;;
    esac
done
OPTIND=1
if [[ ${is_quiet} -eq 0 ]]; then
    # Redirect stdout to /dev/null
    exec > /dev/null
fi

#########################################################
#                       Banner
#########################################################
echo "          ___  __   __    ___ "
echo " /\  |  |  |  /  \ / _\` |  |  "
echo "/~~\ \__/  |  \__/ \__> |  |  "
echo "                              "

#########################################################
#                       Help : -h
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        h) #Print help
            usage
            exit
            ;;
    esac
done
OPTIND=1

#########################################################
#       Initiatlize script configuration from CLI
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        k)
            ssh_key="${OPTARG}"
            ;;
        c)
            git_clone_url="${OPTARG}"
            ;;
        f)
            commit_msg_from_file=$(cat "${OPTARG}")
            ;;
        m)
            commit_msg_text="${OPTARG}"
            ;;
        a)
            git_add_untracked=0
            ;;
        o)
            read_only=0
            ;;
        x)
            git_remote="${OPTARG}"
            ;;
    esac
done
OPTIND=1

#########################################################
#             Reposirory: -r <path>      
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        r)  
            # Parse comma separated values since IFS includes the comma.
            read -ra repositories <<< "${OPTARG}"

            for folder in "${repositories[@]}"; do
                # Check repo exist and contains .git folder
                if [[ -d "$folder" ]]; then
                    cd "$folder"
                    if [[ ! -d .git ]]; then
                        >&2 echo "[ERROR] Folder $folder is not a git repository."
                        exit 4
                    fi
                    # Fetch last commits
                    git_command git fetch --quiet
                    branch=$(git rev-parse --abbrev-ref HEAD) # Figure out branch
                else
                    # Init repository
                    if [[ -n "${git_clone_url}" ]]; then
                        echo "[INFO] Local repository do no exist, initating it from ${git_clone_url}"
                        cd "${init_folder}"
                        cd "$(dirname "${folder}")"
                        git_command git clone "${git_clone_url}"
                        cd "${init_folder}" && cd "${folder}"
                        branch=$(git rev-parse --abbrev-ref HEAD) # Figure out branch
                    else
                        >&2 echo "[ERROR] Repository $folder do not exist and '-c <URL>' is not set. Please set git server URL to be able to initiate the repo."
                        exit 4
                    fi
                fi
                echo "[INFO] Repository $folder is on branch ${branch}"
                # Setting no edit merge option so git won't open editor and accept default merge message if any, when doing git pull
                git config core.mergeoptions --no-edit
                # Setting host key check to no so git won't ask for user input to validate server identity
                git config core.sshCommand 'ssh -o StrictHostKeyChecking=no'
                # Setting pager to cat to avoid less paging
                git config core.pager cat
                # Don't consider trailing space change as a cause for merge conflicts
                git config core.whitespace -trailing-space
                # Use abbrev SHAs whenever possible/relevant instead of full 40 chars
                git config log.abbrevCommit true
                # Enable colors in color-supporting terminals
                git config color.ui auto
                # Configs from https://gist.github.com/tdd/470582 and https://gist.github.com/pksunkara/988716
                
                cd "${init_folder}"
            done
            ;;
    esac
done
OPTIND=1

# No repository selected failure
if [[ ${#repositories[@]} -eq 0 ]]; then
    >&2 echo "[ERROR] You need to set the repository '-r <Path(s)>'."
    exit 5
fi 

#########################################################
#               Reset: -t <sha>      
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        t) #Reseting to previous commit
            for folder in "${repositories[@]}"; do
                echo "[INFO] Reseting ${folder} to ${OPTARG} commit"
                cd "$folder"
                git reset --hard "${OPTARG}"
                cd "${init_folder}"
                break
            done
            echo "[INFO] Reset done"
            exit
            ;;
    esac
done
OPTIND=1

#########################################################
#               Checkout: -b <branch>      
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        b) #Checkout
            newbranch="${OPTARG}"
            for folder in "${repositories[@]}"; do
                echo "[INFO] Switching repository ${folder} on branch ${newbranch}"
                cd "$folder"
                branch=$(git rev-parse --abbrev-ref HEAD) # Figure out branch
                if [[ ! "${newbranch}" == "${branch}" ]]; then
                    if ! is_changes_in_tracked_files; then
                        # Check local branches
                        local_branches="$(git_command git branch | sed 's/^[ ]\+//' | grep -v 'HEAD')"
                        if [ -n "$(echo ${local_branches} | grep ${newbranch})" ]; then
                            echo "[INFO] Checking out local branch ${newbranch}"
                            git checkout "${newbranch}"
                            continue
                        fi
                        # Check remote branches
                        remote_branches="$(git_command git branch -r | sed 's/^[ ]\+//' | grep -v 'HEAD')"
                        if [ -n "$(echo ${remote_branches} | grep ${newbranch})" ]; then
                            echo "[INFO] Checking out remote branch ${newbranch}"
                            git_command git fetch --quiet "${git_remote}" "${newbranch}:${newbranch}"
                            if ! git branch -u "${git_remote}/${newbranch}" "$newbranch"
                            then
                                # Older versions of git (1.7)
                                git branch --set-upstream "$newbranch" "${git_remote}/${newbranch}"
                            fi
                            git checkout "${newbranch}"
                            continue
                        fi
                        # Create the branch
                        echo "[INFO] Creating a new branch ${newbranch}"
                        git checkout -b "${newbranch}"
                        branch=$(git rev-parse --abbrev-ref HEAD) # Figure out branch
                        if [[ $read_only -eq 0 ]]; then
                            echo "[INFO] Read only: would have push new branch"
                        else
                            git_command git push -u "${git_remote}" "${branch}"
                        fi
                    else
                        >&2 echo "[ERROR] Can't checkout with changed files in working tree, please merge changes first." 
                        exit 6
                    fi
                else
                    echo "[INFO] Already on branch ${newbranch}"
                fi
                cd "${init_folder}"
            done
            ;;
    esac
done
OPTIND=1

#########################################################
#               Update: -u <stategy>      
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        u)
            # Check if strategy string valid
            strategy=${OPTARG}
            if [[ ! "${strategy}" = "merge" ]] && [[ ! "${strategy}" = "pull" ]] && [[ ! "${strategy}" = "merge-overwrite" ]] && [[ ! "${strategy}" = "merge-or-branch" ]] && [[ ! "${strategy}" = "merge-or-stash" ]] && [[ ! "${strategy}" = "merge-or-fail" ]] && [[ ! "${strategy}" = "stash" ]]; then
                >&2 echo -e "[ERROR] Unkwown strategy ${strategy}. See '$0 -h' for help" 
                exit 3
            fi

            for folder in "${repositories[@]}"; do
                
                cd "$folder"
                echo "[INFO] Updating ${folder}"

                committed_changes=1

                #########################################################
                #              Saving changes as stash
                #########################################################

                # If there is any kind of changes in the working tree
                if [[ -n $(git status -s) ]]; then
                    
                    echo "[INFO] Locally changed files:"
                    git status -s

                    # Adding untracked files if specified
                    if [[ ${git_add_untracked} -eq 0 ]]; then
                        echo "[INFO] Adding untracked files"
                        git ls-files -o | while read -r file
                        do
                            git add "$file"
                        done
                    fi

                    # If staged or unstaged changes in the tracked files in the working tree
                    if is_changes_in_tracked_files; then
                    
                        # Save stash
                        echo "[INFO] Saving changes as a stash."
                        if ! git stash save "${commit_and_stash_name}"; then
                            >&2 echo "[WARNING] Unable to save stash"
                            # Get conflicting files list
                            conflicting_files=$(git diff --name-only --diff-filter=U)
                            if [[ -n "${conflicting_files}" ]]; then
                                >&2 echo "[WARNING] Already in the middle of a conflict with files:"
                                echo "${conflicting_files}"
                            else
                                >&2 echo "[WARNING] Unknow issue with the 'git stash' command"
                            fi
                            if [[ ! "${strategy}" =~ "merge-or-fail" ]]; then
                                >&2 echo "[ERROR] Use '-t <Commit SHA>' to hard reset to previous commit" 
                                >&2 echo "[ERROR] Use '-u merge-or-fail' to continue and pull changes even if 'git stash' fails"
                                >&2 echo "[ERROR] Or solve this issue manually from ${host}:${folder}" 
                                exit 7
                            fi
                        else
                            if [[ -z $(git stash list | grep "${date_time_str}") ]] && [[ ! "${strategy}" =~ "merge-or-fail" ]]; then
                                >&2 echo "[ERROR] Looks like your stash could not be saved" 
                                >&2 echo "[ERROR] Use '-u merge-or-fail' to continue and pull changes even if 'git stash' fails"
                                exit 8
                            fi
                        fi

                        # Apply changes if merge strategy is not stash and the stash exists
                        if [[ ! "${strategy}" = "stash" ]]; then
                            if [[ -n $(git stash list | grep "${date_time_str}") ]]; then
                                echo "[INFO] Applying stash"
                                git stash apply --quiet "stash@{0}"
                            else
                                >&2 echo "[WARNING] Your changes are not saved as stash" 
                                >&2 echo "[WARNING] Hit Ctrl+C now to cancel, or wait 5 seconds"
                                sleep 5
                            fi
                            # Only commit if strategy is to merge. 
                            if [[ "${strategy}" =~ "merge" ]]; then
                                commit_local_changes
                                committed_changes=0
                            fi
                        fi
                    else
                        echo "[INFO] No local changes in tracked files"
                    fi
                else
                    echo "[INFO] No local changes"
                fi

                #########################################################
                #                       Merging changes
                #########################################################
                echo "[INFO] Pulling changes"
                branch=$(git rev-parse --abbrev-ref HEAD) # Figure out branch

                # Like git pull --no-edits but compatible with git < 1.8
                GIT_MERGE_AUTOEDIT=no
                export GIT_MERGE_AUTOEDIT 

                if ! git_command git pull "${git_remote}" "${branch}"
                then

                    #########################################################
                    #      merge-or-stash conflict resolution strategy
                    #########################################################
                    if [[ "${strategy}" =~ "merge-or-stash" ]]; then
                        >&2 echo "[WARNING] Cannot auto-merge. Reseting to last commit."
                        echo "[INFO] Your changes are saved as git stash \"${commit_and_stash_name}\"" 
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                        git_command git pull "${git_remote}" "${branch}"
                    
                    #########################################################
                    #     merge-overwrite conflict resolution strategy
                    #########################################################
                    elif [[ "${strategy}" =~ "merge-overwrite" ]]; then
                        >&2 echo "[WARNING] Cannot auto-merge. Reseting to last commit"
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                        if ! git_command git pull --quiet --no-commit
                        then
                            # Aborting overwrite '-u merge-overwrite' only tries to look one 
                            # commit behind, and if that commit is also in conflict with remote, then it fails. 
                            >&2 echo "[ERROR] Cannot merge-overwrite: Last commit is also in conflict with remote, too much to handle"
                            >&2 echo "[ERROR] Aborting merge and re-applying stashed changes"
                            git reset --merge
                            git stash apply --quiet "stash@{0}"
                            >&2 echo "[ERROR] Use '-u merge-or-branch' to push changes to new remote branch"
                            >&2 echo "[ERROR] Use '-t <Commit SHA>' to hard reset to previous commit" 
                            >&2 echo "[ERROR] Or merge manually from ${host}:${folder}"
                            >&2 echo "[ERROR] Merge aborted, nothing should have changed" 
                            exit 2
                        fi
                        echo "[INFO] Applying last stash in order to merge"
                        if ! git stash apply --quiet "stash@{0}"
                        then
                            echo "[INFO] Overwriting conflicted files with local changes"
                            # Iterate list of conflicted files and choose stashed version
                            for file in $(git diff --name-only --diff-filter=U); do
                                git checkout --theirs -- "${file}"
                                git add "${file}"
                            done
                        else
                            echo "[INFO] Git stash apply successful, no need to overwrite"
                        fi
                        commit_local_changes

                    #########################################################
                    #     merge-or-branch conflict resolution strategy   
                    #########################################################
                    elif [[ "${strategy}" =~ "merge-or-branch" ]]; then
                        conflit_branch="$(echo "${commit_and_stash_name}" | tr -cd '[:alnum:]')"
                        >&2 echo "[WARNING] Cannot auto-merge. Creating a new branch ${conflit_branch}"
                        git reset --hard HEAD~1
                        git checkout -b "${conflit_branch}"
                        git stash apply --quiet "stash@{0}"
                        commit_local_changes
                        echo "[INFO] Your changes are applied to branch ${conflit_branch}"
                        >&2 echo "[WARNING] Repository is on a new branch"

                    #########################################################
                    #     merge-or-fail conflict resolution strategy   
                    #########################################################
                    elif [[ "${strategy}" =~ "merge-or-fail" ]]; then
                        >&2 echo "[ERROR] Cannot auto-merge."
                        >&2 echo "[ERROR] Use '-t <Commit SHA>' to hard reset to previous commit" 
                        >&2 echo "[ERROR] Or merge manually from ${host}:${folder}"
                        git reset --merge
                        >&2 echo "[ERROR] Merge aborted, nothing should have changed"
                        exit 2
                    
                    #########################################################
                    #     pull conflict resolution strategy   
                    #########################################################
                    elif [[ "${strategy}" =~ "pull" ]]; then
                        >&2 echo "[ERROR] Cannot auto-merge."
                        >&2 echo "[ERROR] Use '-u merge-overwrite' to overwrite remote content"
                        >&2 echo "[ERROR] Use '-u merge-or-branch' to push changes to new remote branch"
                        >&2 echo "[ERROR] Use '-u merge-or-stash' to keep remote changes (stash local changes)"
                        >&2 echo "[ERROR] Use '-t <Commit SHA>' to hard reset to previous commit" 
                        git reset --merge
                        >&2 echo "[ERROR] Merge aborted, nothing should have changed"
                        exit 2
                    
                    #########################################################
                    #     default merge conflict resolution strategy
                    #########################################################
                    else
                        >&2 echo "[ERROR] Cannot auto-merge. Reseting to last commit and re-applying stashed changes."
                        git reset --hard HEAD~1
                        git stash apply --quiet "stash@{0}"
                        >&2 echo "[ERROR] Use '-u merge-overwrite' to overwrite remote content"
                        >&2 echo "[ERROR] Use '-u merge-or-branch' to push changes to new remote branch"
                        >&2 echo "[ERROR] Use '-u merge-or-stash' to keep remote changes (stash local changes)"
                        >&2 echo "[ERROR] Use '-t <Commit SHA>' to hard reset to previous commit" 
                        >&2 echo "[ERROR] Merge aborted, nothing changed." 
                        exit 2
                    fi
                fi

                #########################################################
                #       Push changes to current branch if strategy is to merge  
                #########################################################
                branch=$(git rev-parse --abbrev-ref HEAD) # Figure out branch

                if [[ "${strategy}" =~ "merge" ]]; then
                    # If commits are ready to be pushed       
                    if [[ $committed_changes -eq 0 ]]; then

                        if [[ $read_only -eq 0 ]]; then
                            echo "[INFO] Read only: would have push changes"
                        else
                            echo "[INFO] Pushing changes"
                            git_command git push -u "${git_remote}" "${branch}"
                            git_command git fetch --quiet
                        fi
                    fi
                fi

                cd "${init_folder}"
            done
            ;;
    esac
done
OPTIND=1

#########################################################
#     Clean stashes: -s <Number of stash to keep>      
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        s)
            for folder in "${repositories[@]}"; do
                cd "$folder"
                nb_stash_to_keep=${OPTARG}
                if [[ nb_stash_to_keep -ge 0 ]]; then
                    tail_n_arg="$((nb_stash_to_keep + 1))"
                    stashes=$(git stash list | awk -F ':' '{print$1}' | tail -n+${tail_n_arg})
                    if [[ -n "${stashes}" ]]; then
                        oldest_stash=$(git stash list | grep "stash@{${nb_stash_to_keep}}")
                        echo "[INFO] Cleaning stashes from $folder"
                        # Dropping stashes from the oldest, reverse order
                        for stash in $(echo "${stashes}" | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }'); do
                            if ! git stash drop "${stash}"
                            then
                                stash_name=$(git stash list | grep "${stash}")
                                >&2 echo "[WARNING] A stash could not be deleted: ${stash_name}"
                            fi
                        done
                    fi
                fi
            done
            ;;
    esac
done
OPTIND=1     

#########################################################
#   Show informations: -i <N last commits activity>      
#########################################################
while getopts "${optstring}" arg; do
    case "${arg}" in
        i)
            for folder in "${repositories[@]}"; do
                cd "$folder"
                echo "[INFO] Branches ${folder}"
                git branch -a -vv
                echo "[INFO] Tracked files ${folder}"
                git ls-tree --full-tree -r --name-only HEAD
                echo "[INFO] Last ${OPTARG} commits activity ${folder}"
                git log --graph --date=relative --pretty=tformat:'%Cred%h%Creset%d %s%Cgreen(%an %ad)%Creset' -n "${OPTARG}"                
                echo "[INFO] Git status ${folder}"
                git status
                cd "${init_folder}"
            done
            ;;
    esac
done

echo "[INFO] Success"
