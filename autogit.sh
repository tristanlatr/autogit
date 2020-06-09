#!/bin/bash
# Git automatic administration script

# Install directory
# Resolve current directory path. Code from https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself/246128#246128
# Resolve $SOURCE until the file is no longer a symlink
# If $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"; SOURCE="$(readlink "$SOURCE")"; [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"; done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
# Saves stdout, Restore stdout: `exec 1>&6 6>&- `
exec 6>&1 
# Setting bash strict mode. See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t,'
# SCRIPT CONFIG: Configurable with options -r <> [-k <>] [-c <>] [-a] [-m <>] [-f <>] [-q] [-o]
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
# Add untracked files to git: true/false. Option [-a]
git_add_untracked=false
# Quiet: true/false. Option [-q]
is_quiet=false
# Read only: If set to true equivalent to (repository) read-only: no commit or push changes.
# Will still pull and merge remote changes into working copy!
read_only=false
# SCRIPT VARIABLES
# See help '-h' for more informations
optstring="hqnok:c:m:f:ar:b:t:u:i:s:"
host=`hostname`
init_folder=`pwd`
date_time_str=`date +"%Y-%m-%dT%H-%M-%S"`
commit_and_stash_name="[autogit] Changes on ${host} ${date_time_str}"
# FUNCTIONS
download_docs_if_not_found(){
    if ! [[ -e "$DIR/readme.md" ]]; then
        cd $DIR
        echo "Downloading docs from the internet..."
        wget --quiet https://raw.githubusercontent.com/tristanlatr/autogit/master/readme.md
        cd $init_folder
    fi
}
quick_usage(){
    download_docs_if_not_found
    cat "$DIR/readme.md" | grep "Usage summary"
}
usage(){
    download_docs_if_not_found
    cat "$DIR/readme.md"
}
nofail(){
    if ! $@; then
        >&2 echo "[WARNING] Retrying in 3 seconds. Failed command: $@"
        sleep 3
        if ! $@; then
            >&2 echo "[ERROR] Fatal error. Failed command: $@" ; exit 1
        fi
    fi
}
# Usage: with_ssh_key command --args (required)
with_ssh_key(){
    # echo "[DEBUG] with_ssh_key params: $@"
    # Need to reset the IFS temporarly to space hum...
    IFS=' '
    if [[ ! -z "${ssh_key}" ]] ; then
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=no'
        IFS=' '
        if ! ssh-agent bash -c "ssh-add ${ssh_key} 2>&1 && $*"; then
            >&2 echo "[WARNING] Retrying in 3 seconds. Failed command (with_ssh_key): $*"
            sleep 3
            if ! ssh-agent bash -c "ssh-add ${ssh_key} 2>&1 && $*"; then
                git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
                >&2 echo "[ERROR] Fatal error. Failed command (with_ssh_key): $*" ; exit 1  
            fi
        fi
        IFS=$'\n\t,'
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
    else
        nofail $@
    fi
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
    if [[ $read_only = false ]]; then
        echo "[INFO] Committing changes"
        git add -u
        echo "${commit_msg_text}" "${commit_msg_from_file}" "${commit_and_stash_name}" > /tmp/commit-msg.txt
        nofail git commit -F /tmp/commit-msg.txt
    elif [[ $read_only = true ]]; then
        echo "[INFO] Read only: would have commit changes: ${commit_and_stash_name}"
    fi
}

# Begin of the main program

# Syntax check
while getopts "${optstring}" arg; do
    case "${arg}" in
        h) ;;
        q) ;;
        k) ;;
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

# Setting verbosity
while getopts "${optstring}" arg; do
    case "${arg}" in
        q)
            is_quiet=true
            ;;
    esac
done
OPTIND=1
if [[ "${is_quiet}" = true ]]; then
    exec > /dev/null
fi

# Banner
echo "          ___  __   __    ___ "
echo " /\  |  |  |  /  \ / _\` |  |  "
echo "/~~\ \__/  |  \__/ \__> |  |  "
echo "                              "

# Print help and exit if -h
while getopts "${optstring}" arg; do
    case "${arg}" in
        h) #Print help
            usage
            exit
            ;;
    esac
done
OPTIND=1
# Parse script configuration and init values
while getopts "${optstring}" arg; do
    case "${arg}" in
        k)
            ssh_key=${OPTARG}
            ;;
        c)
            git_clone_url=${OPTARG}
            ;;
        f)
            commit_msg_from_file=`cat "${OPTARG}"`
            ;;
        m)
            commit_msg_text="${OPTARG}"
            ;;
        a)
            git_add_untracked=true
            ;;
        o)
            read_only=true
            ;;
    esac
done
OPTIND=1
# Parse repositories and check them
while getopts "${optstring}" arg; do
    case "${arg}" in
        r)            
            repositories=${OPTARG}
            for folder in ${repositories}; do
                
                if [[ -d "$folder" ]]; then
                    cd $folder
                    if [[ ! -d .git ]]; then
                        >&2 echo "[ERROR] Repository folder must contain a valid .git directory." ; exit 4
                    fi
                    with_ssh_key git fetch --quiet
                    branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
                    echo "[INFO] Check repository $folder on branch ${branch}"
                else
                    if [[ ! -z "${git_clone_url}" ]]; then
                        echo "[INFO] Local repository do no exist, initating it from ${git_clone_url}"
                        cd "${init_folder}"
                        cd "$(dirname ${folder})"
                        with_ssh_key git clone ${git_clone_url}
                        cd "${init_folder}" && cd "${folder}"
                        # git init
                        # git remote add -t master origin ${git_clone_url} 
                        # with_ssh_key git remote update
                        # with_ssh_key git pull
                        branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
                        echo "[INFO] Check repository $folder on branch ${branch}"
                    else
                        >&2 echo "[ERROR] Git reposirtory $folder do not exist and '-c <URL>' is not set. Please set git server URL to be able to initiate the repo."
                        exit 4
                    fi
                fi
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
# Hard reset
while getopts "${optstring}" arg; do
    case "${arg}" in
        t) #Reseting to previous commit
            for folder in ${repositories}; do
                echo "[INFO] Reseting ${folder} to ${OPTARG} commit"
                cd $folder
                git reset --hard ${OPTARG}
                cd "${init_folder}"
                break
            done
            echo "[INFO] Reset done"
            exit
            ;;
    esac
done
OPTIND=1
# Checkout
while getopts "${optstring}" arg; do
    case "${arg}" in
        b) #Checkout
            for folder in ${repositories}; do
                echo "[INFO] Checkout ${folder} on branch ${OPTARG}"
                cd $folder
                branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
                if [[ ! "${OPTARG}" == "${branch}" ]]; then
                    if ! is_changes_in_tracked_files; then
                        if ! git checkout -b ${OPTARG}
                        then
                            git checkout ${OPTARG}
                        fi
                    else
                        >&2 echo "[ERROR] Can't checkout with changed files in working tree, please merge changes first." 
                        exit 6
                    fi
                else
                    echo "[INFO] Already on branch ${OPTARG}"
                fi
                cd "${init_folder}"
            done
            ;;
    esac
done
OPTIND=1
# Update with s
while getopts "${optstring}" arg; do
    case "${arg}" in
        u) #Update
            for folder in ${repositories}; do
                
                cd $folder
                echo "[INFO] Updating ${folder}"
                strategy=${OPTARG}

                if [[ ! "${strategy}" = "merge" ]] && [[ ! "${strategy}" = "merge-overwrite" ]] && [[ ! "${strategy}" = "merge-or-branch" ]] && [[ ! "${strategy}" = "merge-or-stash" ]] && [[ ! "${strategy}" = "merge-or-fail" ]] && [[ ! "${strategy}" = "stash" ]]; then
                    >&2 echo -e "[ERROR] Unkwown strategy ${strategy} '-u <Strategy>' option argument.\nPlease see '$0 -h' for more infos." 
                    exit 3
                fi
                # If there is any kind of changes in the working tree
                if [[ -n `git status -s` ]]; then
                    git_stash_args=""
                    if [[ "${git_add_untracked}" = true ]]; then
                        echo "[INFO] Adding untracked files"
                        git add .
                        git_stash_args="--include-untracked"
                    fi
                    echo "[INFO] Locally changed files:"
                    git status -s
                    # If staged or unstaged changes in the tracked files in the working tree
                    if is_changes_in_tracked_files; then
                        echo "[INFO] Saving changes as a git stash \"${commit_and_stash_name}\"."
                        if ! git stash save ${git_stash_args} "${commit_and_stash_name}"
                        then
                            >&2 echo "[ERROR] Unable to save stash, repository can be in a conflict state" 
                            >&2 echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" 
                            exit 7
                        else
                            if [[ -z `git stash list | grep "${date_time_str}"` ]] && [[ ! "${strategy}" =~ "merge-or-fail" ]]; then
                                >&2 echo "[ERROR] Looks like your stash could not be saved or you have no changes to save, to continue anyway, please use '-u merge-or-fail'" 
                                exit 8
                            fi
                        fi
                        if [[ "${strategy}" =~ "merge" ]]; then
                            if [[ -n `git stash list | grep "${date_time_str}"` ]]; then
                                echo "[INFO] Applying stash in order to merge"
                                git stash apply --quiet stash@{0}
                            else
                                >&2 echo "[WARNING] Your changes are not saved as stash" 
                            fi
                            commit_local_changes
                        fi
                    fi
                else
                    echo "[INFO] No local changes"
                fi
                echo "[INFO] Merging"
                branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
                if ! with_ssh_key git pull origin ${branch}
                then
                    # No error
                    if [[ "${strategy}" =~ "merge-or-stash" ]]; then
                        >&2 echo "[WARNING] Merge failed. Reseting to last commit."
                        echo "[INFO] Your changes are saved as git stash \"${commit_and_stash_name}\"" 
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                        with_ssh_key git pull
                    
                    # Force overwrite
                    elif [[ "${strategy}" =~ "merge-overwrite" ]]; then
                        >&2 echo "[WARNING] Merge failed. Reseting to last commit"
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                        if ! with_ssh_key git pull --quiet --no-commit
                        then
                            >&2 echo "[WARNING] Last commit is also in conflict with remote. Giving up."
                            >&2 echo "[ERROR] Merge overwrite failed. Repository is in a conflict state! Trying to apply last stash and quitting"
                            >&2 echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option"
                            git stash apply --quiet stash@{0}
                            exit 2
                        fi
                        echo "[INFO] Applying last stash in order to merge"
                        if ! git stash apply --quiet stash@{0}
                        then
                            echo "[INFO] Overwriting conflicted files with local changes"
                            # Iterate list of conflicted files and choose stashed version
                            for file in `git diff --name-only --diff-filter=U`; do
                                git checkout --theirs -- ${file}
                                git add ${file}
                            done
                        else
                            >&2 echo "[WARNING] Git stash apply successful, no need to overwrite"
                        fi
                        commit_local_changes

                    elif [[ "${strategy}" =~ "merge-or-branch" ]]; then
                        conflit_branch="$(echo ${commit_and_stash_name} | tr -cd '[:alnum:]')"
                        >&2 echo "[WARNING] Merge failed. Creating a new remote branch ${conflit_branch}"
                        git reset --hard HEAD~1
                        git checkout -b ${conflit_branch}
                        echo "[INFO] Applying stash in order to push to new remote branch"
                        git stash apply --quiet stash@{0}
                        commit_local_changes
                        echo "[INFO] You changes will be pushed to remote branch ${conflit_branch}. Please merge the branch"
                        >&2 echo "[WARNING] Repository is on a new branch"

                    elif [[ "${strategy}" =~ "merge-or-fail" ]]; then
                        >&2 echo "[ERROR] Merge failed. Repository is in a conflict state!"
                        >&2 echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" 
                        exit 2
                    
                    else
                        >&2 echo "[WARNING] Merge failed. Reseting to last commit and re-applying stashed changes."
                        git reset --hard HEAD~1
                        git stash apply --quiet stash@{0}
                        echo "[INFO] Use '-u merge-overwrite' to overwrite remote content"
                        echo "[INFO] Use '-u merge-or-branch' to push changes to new remote branch"
                        echo "[INFO] Use '-u merge-or-stash' to keep remote changes (stash local changes)"
                        echo "[INFO] Or you can hard reset to previous commit using '-t <Commit SHA>' option. Your local changes will be erased."
                        >&2 echo "[ERROR] Merge failed, nothing changed." 
                        exit 2
                    fi
                else
                    echo "[INFO] Merge success"
                fi
                branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
                if [[ "${strategy}" =~ "merge" ]] && [[ -n `git diff --stat --cached origin/${branch}` ]]; then
                    if [[ $read_only = true ]]; then
                        echo "[INFO] Read only: would have push changes"
                    else
                        echo "[INFO] Pushing changes"
                        with_ssh_key git push -u origin ${branch} 2>&1
                    fi
                fi

                cd "${init_folder}"
            done
            ;;
    esac
done
OPTIND=1
# Clean stashes
while getopts "${optstring}" arg; do
    case "${arg}" in
        s)
            for folder in ${repositories}; do
                cd $folder
                nb_stash_to_keep=${OPTARG}
                if [[ nb_stash_to_keep -ge 0 ]]; then
                    tail_n_arg=$(( ${nb_stash_to_keep} + 1))
                    stashes=`git stash list | awk -F ':' '{print$1}' | tail -n+${tail_n_arg}`
                    if [[ -n "${stashes}" ]]; then
                        oldest_stash=`git stash list | grep "stash@{${nb_stash_to_keep}}"`
                        echo "[INFO] Cleaning stashes $folder"
                        # Dropping stashes from the oldest, reverse order
                        for stash in `echo "${stashes}" | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }'`; do
                            if ! git stash drop "${stash}"
                            then
                                stash_name=`git stash list | grep "${stash}"`
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
# Show informations
while getopts "${optstring}" arg; do
    case "${arg}" in
        i)
            for folder in ${repositories}; do
                cd $folder
                echo "[INFO] Branches ${folder}"
                git --no-pager branch -a -vv        
                echo "[INFO] Tracked files ${folder}"
                git ls-tree --full-tree -r --name-only HEAD
                echo "[INFO] Last ${OPTARG} commits activity ${folder}"
                git --no-pager log -n ${OPTARG} --graph                
                echo "[INFO] Git status ${folder}"
                git status
                cd "${init_folder}"
            done
            ;;
    esac
done
shift "$((OPTIND-1))"
echo "[INFO] Success"