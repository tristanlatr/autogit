#!/bin/bash
# Git administration script
# Version 2 Edited 2020

# Setting bash strict mode. See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t,'

# Script constants
host=`hostname`
init_folder=`pwd`
optstring="hqnk:c:m:f:ar:b:t:u:i:"
nb_stash_to_keep=100

# Script config
repositories=()
ssh_key=""
git_clone_url=""
commit_msg_from_file=""
commit_msg_text=""
git_add_untracked=false
is_quiet=false
dry_mode=false

quick_usage(){
    usage="
    Usage: $0 [-h] [-q] [-n] [-k <SSH Key>] [-c <Git clone URL>] [-b <Branch>] 
    [-u <Strategy>] [-a] [-m <Commit msg text> ][-f <Commit msg file>] 
    [-t <Commit hash to reset>] [-i <Number of commits to show>]
    -r <Repository path>"
    echo "${usage}"
}

usage(){
    long_usage="
    This script is designed to programatically update a git repository: pull and push changes from and to a one or several repositories.
        
    The script doesn't work if there is a merge conflict in your repo.

    This script can leave your repo in a merge conflict.
    
    Options:

        -h      Print this help message.
       
        -k <Key>    Path to a trusted ssh key to authenticate against the git server (push). Required if git authentication is not already working with default key.
        
        -c <Url>    URL of the git source. The script will use 'git remote add origin URL' if the repo folder doesn't exist and init the repo on master branch. Required if the repo folder doesn't exists. Warning, if you declare several repositories, the same URL will used for all. Multiple repo values are not supported by this feature.
        
        -r <Paths>  Path to managed repository, can be multiple comma separated. Only remote 'origin' can be used. Warning make sure all repositories exists, multiple repo values are not supported by the git clone feature '-c'. Repository path(s) should end with the default git repo folder name after git clone. Required.
        
        -b <Branch> Switch to the specified branch or tag. Fail if changed files in working tree, please merge changes first.
        
        -u <Strategy>   Update the current branch from and to upstream, can adopt 6 strategies. This feature supports multiple repo values !
          
            - 'merge' -> Default merge. Save changes as stash and apply them (if any), commit, pull and push, if pull fails, reset pull and re-apply saved changes (leaving the repo in the same state as before calling the script). Exit with code 2 if merge failed. Require a write access to git server.
            
            - 'merge-overwrite' -> Keep local changes. Save changes as stash and apply them (if any), commit, pull and push, if pull fails, reset, pull, re-apply saved changes, merge accept only local changes (overwrite), commit and push to remote. Warning, the overwrite might fail leaving the repository in a conflict state if you edited local files. Exit with code 2 if overwrite failed. Require a write access to git server.
           
            - 'merge-or-stash' -> Keep remote changes. Save changes as stash and apply them (if any), commit, pull and push, if pull fails, revert commit and pull (your changes will be saved as git stash). Exit with code 2 if merge failed. Require a write access to git server.    
          
            - 'merge-or-branch' -> Merge or create a new remote branch. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, create a new branch and push changes to remote leaving the repository in a new branch. Exit with code 2 if merge failed. Require a write access to git server.
          
            - 'merge-or-fail' -> Merge or leave the reposity in a conflict. Warning if there is a conflict. Save changes as stash and apply them (if-any) (Warning: this step can fail, the sctipt will continue without saving the stash), commit, pull and push, if pull fails, leave the git repositiry in a conflict state with exit code 2. Require a write access to git server.
         
            - 'stash' -> Always update from remote. Stash the changes and pull. Do not require a write acces to git server.

        -a  Add untracked files to git. To use with '-u <Strategy>'.
        
        -m <Commit msg text>    The text will be used as the fist line of the commit message, then the generated name with timestamp and then the file content. This can be used with '-f'. To use with '-u <Strategy>'.
        
        -f <Commit msg file>    Specify a commit message from a file. To use with '-u <Strategy>'.
        
        -t <CommitSAH1> Hard reset the local branch to the specified commit. Multiple repo values are not supported by this feature
        
        -i <Number of commits to show>  Shows tracked files, git status and commit history of last N commits.

        -q      Be quiet, to not print anything except errors and informations if you ask for it with '-i <n>'.

        -n      Dry mode. Do not commit or push. If you specify an update strategy with '-u <Strategy>', the script will still pull and merge remote changes into working copy.

    Examples : 

        $ $0 -r ~/isrm-portal-conf/ -b stable -u merge -i 5
        Checkout the stable branch, pull changes and show infos of the repository (last 5 commits).
        $ '$0 -r ~/isrm-portal-conf/ -t 00a3a3f'
        Hard reset the repository to the specified commit.
        $ '$0 -k ~/.ssh/id_rsa2 -c git@github.com:mfesiem/msiempy.git -r ./test/msiempy/ -u merge'
        Init a repo and pull (master by default). Use the specified SSH to authenticate.

    Return codes : 
    
    1 Other errors
    2 Git merge failed
    3 Syntax mistake
    4 Git reposirtory does't exist and '-c URL' is not set
    5 Repository not set
    6 Can't checkout with changed files in working tree
    7 Already in the middle of a merge
    8 Stash could not be saved
    "
    quick_usage
    echo "${long_usage}" | fold -s
}

# Usage: commit_local_changes "dry_mode (required true/false)" "name (required)" "msg text (not required)" "msg text from file (not required)"
commit_local_changes(){
    dry_mode=$1
    if [[ $dry_mode = false ]]; then
        echo "[INFO] Committing changes"
        if [[ "$#" -eq 1 ]] ; then
            git commit -a -m "${1}"
        elif [[ "$#" -eq 2 ]]; then
            git commit -a -m "${2}" -m "${1}"
        elif [[ "$#" -eq 3 ]]; then
            git commit -a -m "${2}" -m "${1}" -m "${3}"
        fi
    elif [[ $dry_mode = true ]]; then
        echo "[INFO] Dry mode: would have commit changes: $2"
    fi
}

# Usage: with_ssh_key "command --args" "ssh key path (not required)"
with_ssh_key(){
    # echo "[DEBUG] with_ssh_key param: $@"
    if [[ "$#" -eq 2 ]] && [[ ! -z "$2" ]]; then
        echo "[INFO] Using SSH key"
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=no'
        if ! ssh-agent bash -c "ssh-add $2 && $1"
        then
            git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
            return 1
        else
            git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
        fi
    else
        if ! bash -c $1
        then
            return 1
        fi
    fi
}

# Usage logger "quiet: <true/false> (required)" command --args (required)
logger() {
    is_quiet=$1
    shift
    if [[ "${is_quiet}" = true ]]; then
        stdout="/tmp/command-stdout.txt"
        stderr='/tmp/command-stderr.txt'
        if ! $@ </dev/null >$stdout 2>$stderr
        then
            cat $stderr >&2
            rm -f $stdout $stderr
            return 1
        fi
        # echo -e "[DEBUG] Command: $@ \n\tOutput : `cat $stdout`"
        rm -f $stdout $stderr
    else
        if ! $@
        then
            return 1
        fi
    fi
}

# Usage: exec_or_fail command --args (required)
exec_or_fail(){
    if ! $@
    then
        echo "[ERROR] Unhandled error, command failed: $@"
        exit 1
    fi
}

is_changes_in_tracked_files(){
    if ! git diff-files --quiet -- || ! git diff-index --quiet --cached --exit-code HEAD
    then
        return 0
    else
        return 1
    fi
}

while getopts "${optstring}" arg; do
    case "${arg}" in
        h) ;;
        q) ;;
        k) ;;
        n) ;;
        c) ;;
        m) ;;
        f) ;;
        a) ;;
        r) ;;
        b) ;;
        t) ;;
        u) ;;
        i) ;;
        *)
            quick_usage
            echo "[ERROR] You made a syntax mistake calling the script. Please see '$0 -h' for more infos." | fold -s
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

logger $is_quiet echo "          ___  __   __    ___ ";
logger $is_quiet echo " /\  |  |  |  /  \ / _\` |  |  ";
logger $is_quiet echo "/~~\ \__/  |  \__/ \__> |  |  ";
logger $is_quiet echo "                              ";

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
            logger $is_quiet echo "[INFO] SSH key: ${ssh_key}"
            ;;
        c)
            git_clone_url=${OPTARG}
            logger $is_quiet echo "[INFO] Git server URL: ${git_clone_url}"
            ;;
        f)
            commit_msg_from_file=`cat "${OPTARG}"`
            logger $is_quiet echo "[INFO] Commit message file: ${OPTARG}"

            ;;
        m)
            commit_msg_text="${OPTARG}"
            logger $is_quiet echo "[INFO] Commit message: ${OPTARG}"
            ;;
        a)
            git_add_untracked=true
            ;;
        n)
            dry_mode=true
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
                    exec_or_fail logger $is_quiet with_ssh_key "git fetch --quiet" "${ssh_key}"
                    branch=`git rev-parse --abbrev-ref HEAD`
                    logger $is_quiet echo "[INFO] Check repository $folder on branch ${branch}"
                else
                    if [[ ! -z "${git_clone_url}" ]]; then
                        logger $is_quiet echo "[INFO] Repository do no exist, initating it."
                        mkdir -p ${folder}
                        cd ${folder}
                        exec_or_fail logger $is_quiet git init
                        exec_or_fail logger $is_quiet git remote add -t master origin ${git_clone_url} 
                        exec_or_fail logger $is_quiet with_ssh_key "git remote update" "${ssh_key}"
                        exec_or_fail logger $is_quiet with_ssh_key "git pull" "${ssh_key}"
                        branch=`git rev-parse --abbrev-ref HEAD`
                        logger $is_quiet echo "[INFO] Check repository $folder on branch ${branch}"
                    else
                        echo "[ERROR] Git reposirtory $folder do not exist and '-c <URL>' is not set. Please set git server URL to be able to initiate the repo." |  fold -s
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
                logger $is_quiet echo "[INFO] Reseting ${folder} to ${OPTARG} commit"
                cd $folder
                exec_or_fail logger $is_quiet git reset --hard ${OPTARG}
                cd "${init_folder}"
                break
            done
            logger $is_quiet echo "[INFO] Reset done"
            exit
            ;;
    esac
done
OPTIND=1
while getopts "${optstring}" arg; do
    case "${arg}" in
        b) #Checkout
            for folder in ${repositories}; do
                logger $is_quiet echo "[INFO] Checkout ${folder} on branch ${OPTARG}"
                cd $folder
                branch=`git rev-parse --abbrev-ref HEAD`
                if [[ ! "${OPTARG}" == "${branch}" ]]; then
                    if ! is_changes_in_tracked_files; then
                        if ! logger $is_quiet git checkout -b ${OPTARG}
                        then
                            exec_or_fail logger $is_quiet git checkout ${OPTARG}
                        fi
                    else
                        echo "[ERROR] Can't checkout with changed files in working tree, please merge changes first." | fold -s
                        exit 6
                    fi
                else
                    logger $is_quiet echo "[INFO] Already on branch ${OPTARG}"
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
                logger $is_quiet echo "[INFO] Updating ${folder}"
                strategy=${OPTARG}

                if [[ ! "${strategy}" = "merge" ]] && [[ ! "${strategy}" = "merge-overwrite" ]] && [[ ! "${strategy}" = "merge-or-branch" ]] && [[ ! "${strategy}" = "merge-or-stash" ]] && [[ ! "${strategy}" = "merge-or-fail" ]] && [[ ! "${strategy}" = "stash" ]]; then
                    echo -e "[ERROR] Unkwown strategy ${strategy} '-u <Strategy>' option argument.\nPlease see '$0 -h' for more infos." | fold -s
                    exit 3
                fi
                # If there is any kind of changes in the working tree
                if [[ -n `git status -s` ]]; then
                    git_stash_args=""
                    commit_and_stash_date=`date +"%Y-%m-%dT%H-%M-%S"`
                    commit_and_stash_name="[autogit] Changes on ${host} ${commit_and_stash_date}"

                    if [[ "${git_add_untracked}" = true ]]; then
                        logger $is_quiet echo "[INFO] Adding untracked files"
                        exec_or_fail logger $is_quiet git add .
                        git_stash_args="--include-untracked"
                    fi

                    logger $is_quiet echo "[INFO] Locally changed files:"
                    logger $is_quiet git status -s

                    # If staged or unstaged changes in the tracked files in the working tree
                    if is_changes_in_tracked_files; then
                        logger $is_quiet echo "[INFO] Saving changes as a git stash \"${commit_and_stash_name}\"."

                        if ! logger $is_quiet git stash save ${git_stash_args} "${commit_and_stash_name}"
                        then
                            echo "[ERROR] Unable to save stash, repository can be in a conflict state"
                            echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" | fold -s
                            exit 7
                        else
                            if [[ -z `git stash list | grep "${commit_and_stash_date}"` ]] && [[ ! "${strategy}" =~ "merge-or-fail" ]]; then
                                echo "[ERROR] Looks like your stash could not be saved or you have no changes to save, to continue anyway, please use '-u merge-or-fail'" | fold -s
                                exit 8
                            fi
                        fi

                        if [[ "${strategy}" =~ "merge" ]]; then
                            if [[ -n `git stash list | grep "${commit_and_stash_date}"` ]]; then
                                logger $is_quiet echo "[INFO] Applying stash in order to merge"
                                exec_or_fail logger $is_quiet git stash apply --quiet stash@{0}
                            else
                                logger $is_quiet echo "[WARNING] Your changes are not saved as stash"
                            fi

                            exec_or_fail logger $is_quiet commit_local_changes "$dry_mode" "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"
                        fi
                    fi

                else
                    logger $is_quiet echo "[INFO] No local changes"
                fi

                logger $is_quiet echo "[INFO] Merging"
                if ! logger $is_quiet with_ssh_key "git pull --quiet" "${ssh_key}"
                then
                    # No error
                    if [[ "${strategy}" =~ "merge-or-stash" ]]; then
                        logger $is_quiet echo "[WARNING] Merge failed. Reseting to last commit."
                        logger $is_quiet echo "[INFO] Your changes are saved as git stash \"${commit_and_stash_name}\"" | fold -s
                        exec_or_fail logger $is_quiet git reset --hard HEAD~1
                        logger $is_quiet echo "[INFO] Pulling changes"
                        exec_or_fail logger $is_quiet with_ssh_key "git pull" "${ssh_key}"
                    
                    # Force overwrite
                    elif [[ "${strategy}" =~ "merge-overwrite" ]]; then
                        logger $is_quiet echo "[WARNING] Merge failed. Reseting to last commit"
                        exec_or_fail logger $is_quiet git reset --hard HEAD~1
                        logger $is_quiet echo "[INFO] Pulling changes"
                        if ! logger $is_quiet with_ssh_key "git pull --quiet --no-commit" "${ssh_key}"
                        then
                            logger $is_quiet echo "[WARNING] Last commit is also in conflict with remote. Giving up."
                            echo "[ERROR] Merge overwrite failed. Repository is in a conflict state! Trying to apply last stash and quitting" | fold -s
                            echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" | fold -s
                            exec_or_fail logger $is_quiet git stash apply --quiet stash@{0}
                            exit 2
                        fi
                        logger $is_quiet echo "[INFO] Applying last stash in order to merge"
                        if ! logger $is_quiet git stash apply --quiet stash@{0}
                        then
                            logger $is_quiet echo "[INFO] Overwriting conflicted files with local changes"
                            # Iterate list of conflicted files and choose stashed version
                            for file in `git diff --name-only --diff-filter=U`; do
                                exec_or_fail logger $is_quiet git checkout --theirs -- ${file}
                                exec_or_fail logger $is_quiet git add ${file}
                            done
                        else
                            logger $is_quiet echo "[WARNING] Git stash apply successful, no need to overwrite"
                        fi
                        exec_or_fail logger $is_quiet commit_local_changes "$dry_mode" "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"

                    elif [[ "${strategy}" =~ "merge-or-branch" ]]; then
                        conflit_branch="$(echo ${commit_and_stash_name} | tr -cd '[:alnum:]')"
                        logger $is_quiet echo "[WARNING] Merge failed. Creating a new remote branch ${conflit_branch}"
                        exec_or_fail logger $is_quiet git reset --hard HEAD~1
                        exec_or_fail logger $is_quiet git checkout -b ${conflit_branch}
                        logger $is_quiet echo "[INFO] Applying stash in order to push to new remote branch"
                        exec_or_fail logger $is_quiet git stash apply --quiet stash@{0}
                        exec_or_fail logger $is_quiet commit_local_changes "$dry_mode" "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"
                        logger $is_quiet echo "[INFO] You changes will be pushed to remote branch ${conflit_branch}. Please merge the branch"
                        echo "[WARNING] Repository is on a new branch"

                    elif [[ "${strategy}" =~ "merge-or-fail" ]]; then
                        echo "[ERROR] Merge failed. Repository is in a conflict state!"
                        echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" | fold -s
                        exit 2
                    
                    else
                        logger $is_quiet echo "[WARNING] Merge failed. Reseting to last commit and re-applying stashed changes."
                        exec_or_fail logger $is_quiet git reset --hard HEAD~1
                        exec_or_fail logger $is_quiet git stash apply --quiet stash@{0}
                        logger $is_quiet echo "[INFO] Use '-u merge-overwrite' to overwrite remote content"
                        logger $is_quiet echo "[INFO] Use '-u merge-or-branch' to push changes to new remote branch"
                        logger $is_quiet echo "[INFO] Use '-u merge-or-stash' to keep remote changes (stash local changes)"
                        logger $is_quiet echo "[INFO] Or you can hard reset to previous commit using '-t <Commit SHA>' option. Your local changes will be erased."
                        echo "[ERROR] Merge failed, nothing changed." | fold -s
                        exit 2
                    fi
                else
                    logger $is_quiet echo "[INFO] Merge success"
                fi
                branch=`git rev-parse --abbrev-ref HEAD`
                if [[ "${strategy}" =~ "merge" ]]; then
                    if [[ $dry_mode = true ]]; then
                        logger $is_quiet echo "[INFO] Dry mode: would have push changes"
                    else
                        logger $is_quiet echo "[INFO] Pushing changes"
                        exec_or_fail logger $is_quiet with_ssh_key "git push -u --quiet origin ${branch}" "${ssh_key}"
                    fi
                fi
                tail_n_arg=$(( ${nb_stash_to_keep} + 2))
                stashes=`git stash list | awk -F ':' '{print$1}' | tail -n+${tail_n_arg}`
                if [[ -n "${stashes}" ]]; then
                    oldest_stash=`git stash list | grep "stash@{${nb_stash_to_keep}}"`
                    logger $is_quiet echo "[INFO] Cleaning stashes"
                    # Dropping stashes from the oldest, reverse order
                    for stash in `echo "${stashes}" | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }'`; do
                        if ! logger $is_quiet  git stash drop "${stash}"
                        then
                            stash_name=`git stash list | grep "${stash}"`
                            logger $is_quiet echo "[WARNING] A stash could not be deleted: ${stash_name}"
                        fi
                    done
                fi
                cd "${init_folder}"
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
logger $is_quiet echo "[INFO] Success"