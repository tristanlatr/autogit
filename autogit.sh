#!/bin/bash
# Git automatic administration script
# Edited 2020-03-15

# Saves stdout, Restore stdout: `exec 1>&6 6>&- `
exec 6>&1 
# Setting bash strict mode. See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t,'
# SCRIPT CONSTANTS
# See help for more informations
optstring="hqnk:c:m:f:ar:b:t:u:i:s:"
# Dry mode: If set to true: Will not commit or push changes.
# Will still pull and merge remote changes into working copy!
dry_mode=false
# SCRIPT CONFIG: Configurable with options -r <> [-k <>] [-c <>] [-a] [-m <>] [-f <>] [-q]
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
# SCRIPT VARIABLES
host=`hostname`
init_folder=`pwd`
# FUNCTIONS
quick_usage(){
    curl https://raw.githubusercontent.com/tristanlatr/autogit/master/readme.md --silent | grep "Usage summary" 
}
usage(){
    curl https://raw.githubusercontent.com/tristanlatr/autogit/master/readme.md --silent
}
# Usage: with_ssh_key command --args (required)
with_ssh_key(){
    # echo "[DEBUG] with_ssh_key params: $@"
    # Need to reset the IFS temporarly to space hum...
    IFS=' '
    if [[ ! -z "${ssh_key}" ]] ; then
        echo "[DEBUG] with_ssh_key params: $*"
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=no'
        IFS=' '
        if ! ssh-agent bash -c "ssh-add ${ssh_key} 2>&1 && $*"; then
            git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
            echo "[ERROR] Fatal error. Failed command: $*" ; exit 1  
        fi
        IFS=$'\n\t,'
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
    else
        if ! $*; then
            echo "[ERROR] Fatal error. Failed command: $*" ; exit 1
        fi
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
# Usage: commit_local_changes "name (required)" "msg text (not required)" "msg text from file (not required)"
commit_local_changes(){
    if [[ $dry_mode = false ]]; then
        echo "[INFO] Committing changes"
        if [[ "$#" -eq 1 ]] ; then
            if ! git commit -a -m "${1}"; then
                echo "[ERROR] Fatal error. Failed command: git commit" ; exit 1
            fi
        elif [[ "$#" -eq 2 ]]; then
            if ! git commit -a -m "${2}" -m "${1}"; then
                echo "[ERROR] Fatal error. Failed command: git commit" ; exit 1
            fi
        elif [[ "$#" -eq 3 ]]; then
            if ! git commit -a -m "${2}" -m "${1}" -m "${3}"; then
                echo "[ERROR] Fatal error. Failed command: git commit" ; exit 1
            fi
        fi
    elif [[ $dry_mode = true ]]; then
        echo "[INFO] Dry mode: would have commit changes: $1"
    fi
}
# Begin of ther
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
        *)
            quick_usage
            echo "[ERROR] You made a syntax mistake calling the script. Please see '$0 -h' for more infos." 
            exit 3
    esac
done
OPTIND=1
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
echo "          ___  __   __    ___ "
echo " /\  |  |  |  /  \ / _\` |  |  "
echo "/~~\ \__/  |  \__/ \__> |  |  "
echo "                              "
while getopts "${optstring}" arg; do
    case "${arg}" in
        h) #Print help
            usage
            exit
            ;;
    esac
done
OPTIND=1
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
    esac
done
OPTIND=1
while getopts "${optstring}" arg; do
    case "${arg}" in
        r)            
            repositories=${OPTARG}
            for folder in ${repositories}; do
                
                if [[ -d "$folder" ]]; then
                    cd $folder
                     with_ssh_key git fetch --quiet
                    branch=`git rev-parse --abbrev-ref HEAD`
                    echo "[INFO] Check repository $folder on branch ${branch}"
                else
                    if [[ ! -z "${git_clone_url}" ]]; then
                        echo "[INFO] Repository do no exist, initating it from ${git_clone_url}"
                        mkdir -p ${folder}
                        cd ${folder}
                        git init
                        git remote add -t master origin ${git_clone_url} 
                         with_ssh_key git remote update
                         with_ssh_key git pull
                        branch=`git rev-parse --abbrev-ref HEAD`
                        echo "[INFO] Check repository $folder on branch ${branch}"
                    else
                        echo "[ERROR] Git reposirtory $folder do not exist and '-c <URL>' is not set. Please set git server URL to be able to initiate the repo."
                        exit 4
                    fi
                fi
                cd "${init_folder}"
            done
            ;;
    esac
done
OPTIND=1
if [[ ${#repositories[@]} -eq 0 ]]; then
    echo "[ERROR] You need to set the repository '-r <Path(s)>'."
    exit 5
fi 
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
while getopts "${optstring}" arg; do
    case "${arg}" in
        b) #Checkout
            for folder in ${repositories}; do
                echo "[INFO] Checkout ${folder} on branch ${OPTARG}"
                cd $folder
                branch=`git rev-parse --abbrev-ref HEAD`
                if [[ ! "${OPTARG}" == "${branch}" ]]; then
                    if ! is_changes_in_tracked_files; then
                        if ! git checkout -b ${OPTARG}
                        then
                            git checkout ${OPTARG}
                        fi
                    else
                        echo "[ERROR] Can't checkout with changed files in working tree, please merge changes first." 
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
while getopts "${optstring}" arg; do
    case "${arg}" in
        u) #Update
            for folder in ${repositories}; do
                
                cd $folder
                echo "[INFO] Updating ${folder}"
                strategy=${OPTARG}

                if [[ ! "${strategy}" = "merge" ]] && [[ ! "${strategy}" = "merge-overwrite" ]] && [[ ! "${strategy}" = "merge-or-branch" ]] && [[ ! "${strategy}" = "merge-or-stash" ]] && [[ ! "${strategy}" = "merge-or-fail" ]] && [[ ! "${strategy}" = "stash" ]]; then
                    echo -e "[ERROR] Unkwown strategy ${strategy} '-u <Strategy>' option argument.\nPlease see '$0 -h' for more infos." 
                    exit 3
                fi
                # If there is any kind of changes in the working tree
                if [[ -n `git status -s` ]]; then
                    git_stash_args=""
                    commit_and_stash_date=`date +"%Y-%m-%dT%H-%M-%S"`
                    commit_and_stash_name="[autogit] Changes on ${host} ${commit_and_stash_date}"

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
                            echo "[ERROR] Unable to save stash, repository can be in a conflict state"
                            echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" 
                            exit 7
                        else
                            if [[ -z `git stash list | grep "${commit_and_stash_date}"` ]] && [[ ! "${strategy}" =~ "merge-or-fail" ]]; then
                                echo "[ERROR] Looks like your stash could not be saved or you have no changes to save, to continue anyway, please use '-u merge-or-fail'" 
                                exit 8
                            fi
                        fi

                        if [[ "${strategy}" =~ "merge" ]]; then
                            if [[ -n `git stash list | grep "${commit_and_stash_date}"` ]]; then
                                echo "[INFO] Applying stash in order to merge"
                                git stash apply --quiet stash@{0}
                            else
                                echo "[WARNING] Your changes are not saved as stash"
                            fi

                             commit_local_changes "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"
                        fi
                    fi

                else
                    echo "[INFO] No local changes"
                fi

                echo "[INFO] Merging"
                if ! with_ssh_key git pull
                then
                    # No error
                    if [[ "${strategy}" =~ "merge-or-stash" ]]; then
                        echo "[WARNING] Merge failed. Reseting to last commit."
                        echo "[INFO] Your changes are saved as git stash \"${commit_and_stash_name}\"" 
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                         with_ssh_key git pull
                    
                    # Force overwrite
                    elif [[ "${strategy}" =~ "merge-overwrite" ]]; then
                        echo "[WARNING] Merge failed. Reseting to last commit"
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                        if ! with_ssh_key git pull --quiet --no-commit
                        then
                            echo "[WARNING] Last commit is also in conflict with remote. Giving up."
                            echo "[ERROR] Merge overwrite failed. Repository is in a conflict state! Trying to apply last stash and quitting" 
                            echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" 
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
                            echo "[WARNING] Git stash apply successful, no need to overwrite"
                        fi
                         commit_local_changes "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"

                    elif [[ "${strategy}" =~ "merge-or-branch" ]]; then
                        conflit_branch="$(echo ${commit_and_stash_name} | tr -cd '[:alnum:]')"
                        echo "[WARNING] Merge failed. Creating a new remote branch ${conflit_branch}"
                        git reset --hard HEAD~1
                        git checkout -b ${conflit_branch}
                        echo "[INFO] Applying stash in order to push to new remote branch"
                        git stash apply --quiet stash@{0}
                        commit_local_changes "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"
                        echo "[INFO] You changes will be pushed to remote branch ${conflit_branch}. Please merge the branch"
                        echo "[WARNING] Repository is on a new branch"

                    elif [[ "${strategy}" =~ "merge-or-fail" ]]; then
                        echo "[ERROR] Merge failed. Repository is in a conflict state!"
                        echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" 
                        exit 2
                    
                    else
                        echo "[WARNING] Merge failed. Reseting to last commit and re-applying stashed changes."
                        git reset --hard HEAD~1
                        git stash apply --quiet stash@{0}
                        echo "[INFO] Use '-u merge-overwrite' to overwrite remote content"
                        echo "[INFO] Use '-u merge-or-branch' to push changes to new remote branch"
                        echo "[INFO] Use '-u merge-or-stash' to keep remote changes (stash local changes)"
                        echo "[INFO] Or you can hard reset to previous commit using '-t <Commit SHA>' option. Your local changes will be erased."
                        echo "[ERROR] Merge failed, nothing changed." 
                        exit 2
                    fi
                else
                    echo "[INFO] Merge success"
                fi
                branch=`git rev-parse --abbrev-ref HEAD`
                if [[ "${strategy}" =~ "merge" ]] && [[ -n `git diff --stat --cached origin/${branch}` ]]; then
                    if [[ $dry_mode = true ]]; then
                        echo "[INFO] Dry mode: would have push changes"
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
                                echo "[WARNING] A stash could not be deleted: ${stash_name}"
                            fi
                        done
                    fi
                fi
            done
            ;;
    esac
done
OPTIND=1     
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