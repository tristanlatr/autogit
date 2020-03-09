#!/bin/bash
# Git administration script
# Edited 2019-03-12

# Setting bash strict mode. See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t,'

quick_usage(){
    usage="
    Usage: $0 [-h] [-q] [-k <SSH Key>] [-c <Git clone URL>] [-b <Branch>] 
    [-u <Strategy>] [-a] [-m <Commit msg text> ][-f <Commit msg file>] 
    [-t <Commit hash to reset>] [-i <Number of commits to show>]
    -r <Repository path>"
    echo "${usage}"
}

usage(){
    long_usage="
    This script is designed to programatically manage merge, pull and push changes from and to a git repository.
        
    The script can't solve merge conflict that already exists before calling the script.
    
    Options:

        -h      Print this help message.
       
        -k <Key>    Path to a trusted ssh key to authenticate against the git server (push). Required if git authentication is not already working with default key.
        
        -c <Url>    URL of the git source. The script will use 'git remote add origin URL' if the repo folder doesn't exist and init the repo on master branch. Required if the repo folder doesn't exists. Warning, if you declare several reposities, the same URL will used for all. Multiple repo values are not supported by this feature.
        
        -r <Paths>  Path to managed repository, can be multiple comma separated. Only remote 'origin' can be used. Warning make sure all repositories exists, multiple repo values are not supported by the git clone feature '-c'. Repository path(s) should end with the default git repo folder name after git clone. Required.
        
        -b <Branch> Switch to the specified branch or tag. Fail if changed files in working tree, please merge changes first.
        
        -u <Strategy>   Update the current branch from and to upstream, can adopt 7 strategies. This feature supports multiple repo values !
          
            - 'merge' -> Default merge. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, reset pull and re-apply saved changes (leaving the repo in the same state as before calling the script). Should exit with code 0. Require a write access to git server.
            
            - 'merge-overwrite' -> Keep local changes. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, reset, pull, re-apply saved changes, accept only local changes in the merge, commit and push to remote. Should exit with code 0. Require a write access to git server.
           
            - 'merge-or-stash' -> Keep remote changes. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, revert commit and pull (your changes will be saved as git stash), exit code 2. Require a write access to git server.    
          
            - 'merge-or-branch' -> Merge or create a new remote branch. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, create a new branch and push changes to remote (leaving the repository in a new branch with exit code 2). Require a write access to git server.
          
            - 'merge-or-fail' -> Merge or leave the reposity in a conflict. Warning if there is a conflict. Save changes as stash (if-any) (this step can fail, the sctipt will continue without saving the stash), apply them, commit, pull and push, if pull fails, will leave the git repositiry in a conflict state with exit code 2. Require a write access to git server.
         
            - 'stash' -> Always update from remote. Stash the changes and pull. Should exit with code 0. Do not require a write acces to git server.

        -a  Add untracked files to git. To use with '-u <Strategy>'.
        
        -m <Commit msg text>    The text will be used as the fist line of the commit message, then the generated name with timestamp and then the file content. This can be used with '-f'. To use with '-u <Strategy>'.
        
        -f <Commit msg file>    Specify a commit message from a file. To use with '-u <Strategy>'.
        
        -t <CommitSAH1> Hard reset the local branch to the specified commit. Multiple repo values are not supported by this feature
        
        -i <Number of commits to show>  Shows tracked files, git status and commit history of last N commits.

        -q      Be quiet, to not print anything except errors.

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

# Usage: commit_local_changes "name  (required)" ["msg text (not required)" "msg text from file (not required)"
commit_local_changes(){
    echo "[INFO] Committing changes"
    if [[ "$#" -eq 1 ]] ; then
        git commit -a -m "${1}"
    elif [[ "$#" -eq 2 ]]; then
        git commit -a -m "${2}" -m "${1}"
    elif [[ "$#" -eq 3 ]]; then
        git commit -a -m "${2}" -m "${1}" -m "${3}"
    fi
}

# with_ssh_key "command" "ssh key path (can be empty)"
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

# stdout "<Quiet true/false>" mycommand args
stdout() {
    quiet=$1
    shift
    if [[ "${quiet}" = true ]]; then
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

#Script configuration
host=`hostname`
init_folder=`pwd`
repositoryIsSet=false
repositories=()
ssh_key=""
git_clone_url=""
commit_msg_from_file=""
commit_msg_text=""
nb_stash_to_keep=10
git_add_untracked=false
optstring="hqk:c:m:f:ar:b:t:u:i:"
quiet=false



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
        *)
            quick_usage
            echo "[ERROR] You made a syntax mistake calling the script. Please see '$0 -h' for more infos." | fold -s
            exit 3
    esac
done
OPTIND=1
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
        q)
            quiet=true
            ;;
    esac
done
OPTIND=1
while getopts "${optstring}" arg; do
    case "${arg}" in
        k)
            ssh_key=${OPTARG}
            stdout "$quiet" echo "[INFO] SSH key: ${ssh_key}"
            ;;
        c)
            git_clone_url=${OPTARG}
            stdout "$quiet" echo "[INFO] Git server URL: ${git_clone_url}"
            ;;
        f)
            commit_msg_from_file=`cat "${OPTARG}"`
            stdout "$quiet" echo "[INFO] Commit message file: ${OPTARG}"

            ;;
        m)
            commit_msg_text="${OPTARG}"
            stdout "$quiet" echo "[INFO] Commit message: ${OPTARG}"
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
                    stdout "$quiet" with_ssh_key "git remote update" "${ssh_key}"
                    branch=`git rev-parse --abbrev-ref HEAD`
                    stdout "$quiet" echo "[INFO] Check repository $folder on branch ${branch}"
                else
                    if [[ ! -z "${git_clone_url}" ]]; then
                        stdout "$quiet" echo "[INFO] Repository do no exist, initating it."
                        mkdir -p ${folder}
                        cd ${folder}
                        stdout "$quiet" git init
                        stdout "$quiet" git remote add -t master origin ${git_clone_url} 
                        stdout "$quiet" with_ssh_key "git remote update" "${ssh_key}"
                        branch=`git rev-parse --abbrev-ref HEAD`
                        stdout "$quiet" echo "[INFO] Check repository $folder on branch ${branch}"
                    else
                        echo "[ERROR] Git reposirtory $folder do not exist and '-c <URL>' is not set. Please set git server URL to be able to initiate the repo." |  fold -s
                        exit 4
                    fi
                fi
                cd "${init_folder}"
            done
            repositoryIsSet=true
            ;;
    esac
done
OPTIND=1
if [[ "$repositoryIsSet" = false ]]; then
    echo "[ERROR] You need to set the repository '-r <Path>'."
    exit 5
fi 
while getopts "${optstring}" arg; do
    case "${arg}" in
        t) #Reseting to previous commit
            for folder in ${repositories}; do
                stdout "$quiet" echo "[INFO] Reseting ${folder} to ${OPTARG} commit"
                cd $folder
                stdout "$quiet" git reset --hard ${OPTARG}
                cd "${init_folder}"
                break
            done
            stdout "$quiet" echo "End (reset)"
            exit
            ;;
    esac
done
OPTIND=1
while getopts "${optstring}" arg; do
    case "${arg}" in
        b) #Checkout
            for folder in ${repositories}; do
                stdout "$quiet" echo "[INFO] Checkout ${folder} on branch ${OPTARG}"
                cd $folder
                branch=`git rev-parse --abbrev-ref HEAD`
                if [[ ! "${OPTARG}" == "${branch}" ]]; then
                    if git diff-files --quiet -- && git diff-index --quiet --cached --exit-code HEAD
                    then
                        if ! stdout "$quiet" git checkout -b ${OPTARG}
                        then
                            stdout "$quiet" git checkout ${OPTARG}
                        fi
                    else
                        echo "[ERROR] Can't checkout with changed files in working tree, please merge changes first." | fold -s
                        exit 6
                    fi
                else
                    stdout "$quiet" echo "[INFO] Already on branch ${OPTARG}"
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
                stdout "$quiet" echo "[INFO] Updating ${folder}"
                strategy=${OPTARG}

                if [[ ! "${strategy}" =~ "merge" ]] && [[ ! "${strategy}" =~ "stash" ]]; then
                    echo "[ERROR] Unkwown strategy ${strategy} '-u <Strategy>' option argument. Please see '$0 -h' for more infos." | fold -s
                    exit 3
                fi
                # If there is any kind of changes in the working tree
                if [[ -n `git status -s` ]]; then
                    git_stash_args=""
                    commit_and_stash_date=`date +"%Y-%m-%dT%H-%M-%S"`
                    commit_and_stash_name="[git-admin] Changes on ${host} ${commit_and_stash_date}"

                    if [[ "${git_add_untracked}" = true ]]; then
                        stdout "$quiet" echo "[INFO] Adding untracked files"
                        stdout "$quiet" git add .
                        git_stash_args="--include-untracked"
                    fi

                    stdout "$quiet" echo "[INFO] Locally changed files:"
                    stdout "$quiet" git status -s

                    # If staged or unstaged changes in the tracked files in the working tree
                    if ! git diff-files --quiet -- || ! git diff-index --quiet --cached --exit-code HEAD
                    then
                        stdout "$quiet" echo "[INFO] Saving changes as a git stash \"${commit_and_stash_name}\"."

                        if ! stdout "$quiet" git stash save ${git_stash_args} "${commit_and_stash_name}"
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
                                stdout "$quiet" echo "[INFO] Applying stash in order to merge"
                                git stash apply --quiet stash@{0}
                            else
                                stdout "$quiet" echo "[WARNING] Your changes are not saved as stash"
                            fi

                            stdout "$quiet" commit_local_changes "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"
                        fi
                    fi

                else
                    stdout "$quiet" echo "[INFO] No local changes"
                fi

                stdout "$quiet" echo "[INFO] Merging"
                if ! stdout "$quiet" with_ssh_key "git pull" "${ssh_key}"
                then
                    # No error
                    if [[ "${strategy}" =~ "merge-or-stash" ]]; then
                        stdout "$quiet" echo "[WARNING] Merge failed. Reseting to last commit."
                        stdout "$quiet" echo "[INFO] Your changes are saved as git stash \"${commit_and_stash_name}\"" | fold -s
                        stdout "$quiet" git reset --hard HEAD~1
                        stdout "$quiet" echo "[INFO] Pulling changes"
                        stdout "$quiet" with_ssh_key "git pull" "${ssh_key}"
                    
                    # Force overwrite
                    elif [[ "${strategy}" =~ "merge-overwrite" ]]; then
                        stdout "$quiet" echo "[WARNING] Merge failed. Overwriting remote."
                        stdout "$quiet" git reset --hard HEAD~1
                        stdout "$quiet" echo "[INFO] Pulling changes with --no-commit flag"
                        if ! stdout "$quiet" with_ssh_key "git pull --no-commit" "${ssh_key}"
                        then
                            stdout "$quiet" echo "[INFO] In the middle of a merge conflict"
                        else
                            stdout "$quiet" echo "[WARNING] Git pull successful, no need to overwrite."
                        fi
                        stdout "$quiet" echo "[INFO] Applying stash in order to merge"
                        if ! git stash apply --quiet stash@{0}
                        then
                            stdout "$quiet" echo "[INFO] Overwriting files with stashed changes"
                            for file in `git ls-tree --full-tree -r --name-only HEAD`; do
                                stdout "$quiet" git checkout --theirs -- ${file}
                                stdout "$quiet" git add ${file}
                            done
                        else
                            stdout "$quiet" echo "[WARNING] Git stash apply successful, no need to overwrite"
                        fi
                        
                        stdout "$quiet" commit_local_changes "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"

                    elif [[ "${strategy}" =~ "merge-or-branch" ]]; then
                        conflit_branch="$(echo ${commit_and_stash_name} | tr -cd '[:alnum:]')"
                        stdout "$quiet" echo "[WARNING] Merge failed. Creating a new remote branch ${conflit_branch}"
                        stdout "$quiet" git reset --hard HEAD~1
                        stdout "$quiet" git checkout -b ${conflit_branch}
                        stdout "$quiet" echo "[INFO] Applying stash in order to push to new remote branch"
                        stdout "$quiet" git stash apply --quiet stash@{0}
                        stdout "$quiet" commit_local_changes "${commit_and_stash_name}" "${commit_msg_text}" "${commit_msg_from_file}"
                        stdout "$quiet" with_ssh_key "git push --quiet -u origin ${conflit_branch}" "${ssh_key}"
                        stdout "$quiet" echo "[INFO] You changes are pushed to remote branch ${conflit_branch}. Please merge the branch"
                        echo "[ERROR] Repository is on a new branch"
                        exit 2

                    elif [[ "${strategy}" =~ "merge-or-fail" ]]; then
                        echo "[ERROR] Merge failed. Repository is in a conflict state!"
                        echo "[ERROR] Please solve conflicts manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option" | fold -s
                        exit 2
                    
                    else
                        stdout "$quiet" echo "[WARNING] Merge failed. Reseting to last commit and re-applying stashed changes."
                        stdout "$quiet" git reset --hard HEAD~1
                        git stash apply --quiet stash@{0}
                        echo "[ERROR] Merge failed, nothing changed. Use '-u merge-overwrite' to overwrite remote content, '-u merge-or-branch' to push changes to new remote branch, '-u merge-or-stash' to keep remote changes (stash local changes). Or you can hard reset to previous commit using '-t <Commit SHA>' option, your local changes will be erased." | fold -s
                        exit 2
                    fi
                else
                    stdout "$quiet" echo "[INFO] Merge success"
                    branch=`git rev-parse --abbrev-ref HEAD`
                    tail_n_arg=$(( ${nb_stash_to_keep} + 2))
                    stashes=`git stash list | awk -F ':' '{print$1}' | tail -n+${tail_n_arg}`
                    if [[ -n "${stashes}" ]]; then
                        oldest_stash=`git stash list | grep "stash@{${nb_stash_to_keep}}"`
                        stdout "$quiet" echo "[INFO] Cleaning stashes"
                        # Dropping stashes from the oldest, reverse order
                        for stash in `echo "${stashes}" | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }'`; do
                            if ! git stash drop --quiet "${stash}"
                            then
                                stash_name=`git stash list | grep "${stash}"`
                                stdout "$quiet" echo "[WARNING] A stash could not be deleted: ${stash_name}"
                            fi
                        done
                    fi
                fi

                if [[ "${strategy}" =~ "merge" ]]; then
                    stdout "$quiet" echo "[INFO] Pushing changes"
                    branch=`git rev-parse --abbrev-ref HEAD`
                    stdout "$quiet" with_ssh_key "git push --quiet -u origin ${branch}" "${ssh_key}"
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
stdout "$quiet" echo "[END] Success"
