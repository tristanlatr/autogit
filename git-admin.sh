#!/bin/bash
# Titles generator from the menu generator.
symbol="*"
paddingSymbol=" "
lineLength=70
function generatePadding() {
    string="";
    for (( i=0; i < $2; i++ )); do
        string+="$1";
    done
    echo "$string";
}
remainingLength=$(( $lineLength - 2 ));
line=$(generatePadding "${symbol}" "${lineLength}");
function generateTitle() {
    totalCharsToPad=$((remainingLength - ${#1}));
    charsToPadEachSide=$((totalCharsToPad / 2));
    padding=$(generatePadding "$paddingSymbol" "$charsToPadEachSide");
    totalChars=$(( ${#symbol} + ${#padding} + ${#1} + ${#padding} + ${#symbol} ));
    echo "$line"
    if [[ ${totalChars} < ${lineLength} ]]; then
        echo "${symbol}${padding}${1}${padding}${paddingSymbol}${symbol}";
    else
        echo "${symbol}${padding}${1}${padding}${symbol}";
    fi
    echo "$line"
}
#Setting bash strict mode. See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t,'

quick_usage(){
    usage="Usage: $0 [-h] [-k <SSH Key>] [-c <Git clone URL>] [-b <Branch>]
    [-u <Strategy>] [-a] [-f <Commit msg file>] 
    [-t <Commit hash to reset>] [-i <Number of commits to show>]
    -r <Repository path(s)>"
    echo "${usage}" | fold -s
}

usage(){
    quick_usage
    usage="
    This script is designed to programatically manage merge, pull and push changes on git repository.
    
    What the script can do:
    
        - Programmatically stash, commit and merge changes from and to remote (to keep local changes and overwrite remote use '-u merge-overwrite').
    
    Options:
        -h      Print this help message.
       
        -k <Key>    Path to a trusted ssh key to authenticate against the git server (push). Required if git authentication is not already working with default key.
        
        -c <Url>    URL of the git source. The script will use 'git remote add origin URL' if the repo folder doesn't exist and init the repo on master branch. Required if the repo folder doesn't exists. Warning, if you declare several reposities, the same URL will used for all. Multiple repo values are not supported by this feature.
        
        -r <Paths>  Path to managed repository, can be multiple comma separated. Only remote 'origin' can be used. Warning make sure all repositories exists, multiple repo values are not supported by the git clone feature '-c'. Repository path(s) should end with the default git repo folder name after git clone. Required.
        
        -b <Branch> Switch to the specified branch or tag. Fail if changed files in working tree, please merge changes first.
        
        -u <Strategy>   Update the current branch from and to upstream, can adopt 7 strategies. This feature supports multiple repo values !
          
            - 'merge' -> Default merge. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, reset pull and re-apply saved changes (leaving the repo in the same state as before calling the script). Require a write access to git server.
            
            - 'merge-overwrite' -> Keep local changes. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, reset, pull, re-apply saved changes, accept only local changes in the merge, commit and push to remote. Require a write access to git server.
           
            - 'merge-or-stash' -> Keep remote changes. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, revert commit and pull (your changes will be saved as git stash) Require a write access to git server.    
          
            - 'merge-or-branch' -> Merge or create a new remote branch. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, create a new branch and push changes to remote (leaving the repository in a new branch). Require a write access to git server.
          
            - 'merge-or-fail' -> Merge or leave the reposity in a conflict. Save changes as stash (if-any) (this step can fail, the sctipt will continue without saving the stash), apply them, commit, pull and push, if pull fails, will leave the git repositiry in a conflict state. Require a write access to git server.
         
            - 'stash' -> Always update from remote. Stash the changes and pull. Do not require a write acces to git server.

        -a  Add untracked files to git. To use with '-u <Strategy>'.
       
        -f <Commit msg file>    Specify a commit message from a file. To use with '-u <Strategy>'.
        
        -t <CommitSAH1> Hard reset the local branch to the specified commit. Multiple repo values are not supported by this feature
        
        -i <Number of commits to show>  Shows tracked files, git status and commit history of last n commits.

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
    6 Can't checkout with unstaged files in working tree
    7 Already in the middle of a merge
    "
    echo "${usage}" | fold -s
}

with_ssh_key(){
    return_val=-1
    if [[ ! -z "$2" ]]; then
        echo "[INFO] Using SSH key"
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=no'
        ssh-agent bash -c "ssh-add $2 && $1"
        return_val=$?
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
    else
        bash -c $1
        return_val=$?
    fi
    return $return_val
}

host=`hostname`
init_folder=`pwd`
repositoryIsSet=false
repositories=()
ssh_key=""
git_clone_url=""
commit_msg=""
git_add_untracked=false
optstring="hk:c:f:ar:b:t:u:i:"
generateTitle "git-admin on ${host}"

while getopts "${optstring}" arg; do
    case "${arg}" in
        h) ;;
        k) ;;
        c) ;;
        f) ;;
        a) ;;
        r) ;;
        b) ;;
        t) ;;
        u) ;;
        i) ;;
        *)
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
        k)
            ssh_key=${OPTARG}
            echo "[INFO] SSH key set ${ssh_key}"
            ;;
        c)
            git_clone_url=${OPTARG}
            echo "[INFO] Git clone URL set ${git_clone_url}"
            ;;
        f)
            echo "[INFO] Commit message set ${OPTARG}"
            commit_msg=`cat "${OPTARG}"`
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
                
                generateTitle "Repository $folder"

                if [[ -d "$folder" ]]; then
                    cd $folder
                    with_ssh_key "git remote update" "${ssh_key}"
                    with_ssh_key "git --no-pager branch -a -vv" "${ssh_key}"
                else
                    if [[ ! -z "${git_clone_url}" ]]; then
                        echo "[INFO] Repository do no exist, initating it."
                        mkdir -p ${folder}
                        cd ${folder}
                        git init
                        git remote add -t master origin ${git_clone_url} 
                        with_ssh_key "git remote update" "${ssh_key}"
                        with_ssh_key "git --no-pager branch -a -vv" "${ssh_key}"
                    else
                        echo "[ERROR] Git reposirtory do not exist and '-c <URL>' is not set. Please set git URL to be able to initiate the repo" |  fold -s
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
    echo "[ERROR] You need to set the repository -r <Path> to continue."
    exit 5
fi 
while getopts "${optstring}" arg; do
    case "${arg}" in
        t) #Reseting to previous commit
            for folder in ${repositories}; do
                generateTitle "[INFO] Reseting ${folder} to ${OPTARG} commit"
                cd $folder
                git reset --hard ${OPTARG}
                cd "${init_folder}"
                break
            done
            generateTitle "End (reset)"
            exit
            ;;
    esac
done
OPTIND=1
while getopts "${optstring}" arg; do
    case "${arg}" in
        b) #Checkout
            for folder in ${repositories}; do
                generateTitle "Checkout ${folder} on branch ${OPTARG}"
                cd $folder
                branch=`git rev-parse --abbrev-ref HEAD`
                if [[ ! "${OPTARG}" == "${branch}" ]]; then
                    if git diff-files --quiet -- && git diff-index --quiet --cached --exit-code HEAD
                    then
                        if ! git checkout -b ${OPTARG}
                        then
                            git checkout ${OPTARG}
                        fi
                    else
                        echo "[ERROR] Can't checkout with changed files in working tree, please merge changes first." | fold -s
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
                generateTitle "Updating ${folder}"
                strategy=${OPTARG}

                if [[ ! "${strategy}" =~ "merge" ]] && [[ ! "${strategy}" =~ "stash" ]]; then
                    echo "[ERROR] Unkwown strategy ${strategy} '-u <Strategy>' option argument. Please see '$0 -h' for more infos." | fold -s
                    exit 3
                fi
                # If there is any kind of changes in the working tree
                if [[ -n `git status -s` ]]; then
                    commit_and_stash_name="[git-admin] Changes on ${host} $(date)"
                    if [[ "${git_add_untracked}" = true ]]; then
                        echo "[INFO] Adding untracked files"
                        git add .
                        git_stash_args="-u -k"
                    fi

                    echo "[INFO] Locally changed files:"
                    git status -s

                    # If staged or unstaged changes in the tracked files in the working tree
                    if ! git diff-files --quiet -- || ! git diff-index --quiet --cached --exit-code HEAD
                    then
                        echo "[INFO] Saving changes as a git stash \"${commit_and_stash_name}\"."

                        if ! git stash save "${commit_and_stash_name}"
                        then
                            echo "[ERROR] Unable to save stash"
                            echo "[INFO] Please solve conflicts and clean working tree manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option, your local changes will be erased." | fold -s
                            generateTitle "End. Error: Repository is in a conflict state"
                            exit 7
                        fi

                        if [[ "${strategy}" =~ "merge" ]]; then
                            echo "[INFO] Applying stash in order to merge"
                            git stash apply --quiet stash@{0}

                            echo "[INFO] Committing changes"
                            if [[ -n "${commit_msg}" ]]; then
                                git commit -a -m "${commit_and_stash_name}" -m "${commit_msg}"
                            else
                                git commit -a -m "${commit_and_stash_name}"
                            fi
                        fi
                    fi

                else
                    echo "[INFO] No local changes"
                fi

                echo "[INFO] Merging"
                if ! with_ssh_key "git pull --no-edit" "${ssh_key}"
                then
                    # No error
                    if [[ "${strategy}" =~ "merge-or-stash" ]]; then
                        echo "[WARNING] Merge failed. Reseting to last commit."
                        echo "[INFO] Your changes are saved as git stash \"${commit_and_stash_name}\"" | fold -s
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                        with_ssh_key "git pull --no-edit" "${ssh_key}"
                    
                    # Force overwrite
                    elif [[ "${strategy}" =~ "merge-overwrite" ]]; then
                        echo "[WARNING] Merge failed. Overwriting remote."
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes with --no-commit flag"
                        if ! with_ssh_key "git pull --no-edit --no-commit" "${ssh_key}"
                        then
                            echo "[INFO] In the middle of a merge conflict"
                        else
                            echo "[WARNING] Git pull successful, no need to overwrite."
                        fi
                        echo "[INFO] Applying stash in order to merge"
                        if ! git stash apply --quiet stash@{0}
                        then
                            echo "[INFO] Overwriting files with stashed changes"
                            for file in `git ls-tree --full-tree -r --name-only HEAD`; do
                                git checkout --theirs -- ${file}
                                git add ${file}
                            done
                        else
                            echo "[WARNING] Git stash apply successful, no need to overwrite"
                        fi
                        echo "[INFO] Committing changes"
                        if [[ -n "${commit_msg}" ]]; then
                            git commit -a -m "[Overwrite]${commit_and_stash_name}" -m "${commit_msg}"
                        else
                            git commit -a -m "[Overwrite]${commit_and_stash_name}"
                        fi

                    elif [[ "${strategy}" =~ "merge-or-branch" ]]; then
                        conflit_branch="$(echo ${commit_and_stash_name} | tr -cd '[:alnum:]')"
                        echo "[WARNING] Merge failed. Creating a new remote branch ${conflit_branch}"
                        git reset --hard HEAD~1
                        git checkout -b ${conflit_branch}
                        echo "[INFO] Applying stash in order to push to new remote branch"
                        git stash apply --quiet stash@{0}
                        echo "[INFO] Committing changes"
                        if [[ -n "${commit_msg}" ]]; then
                            git commit -a -m "[Conflict]${commit_and_stash_name}" -m "${commit_msg}"
                        else
                            git commit -a -m "[Conflict]${commit_and_stash_name}"
                        fi
                        with_ssh_key "git push --quiet -u origin ${conflit_branch}" "${ssh_key}"
                        echo "[INFO] You changes are pushed to remote branch ${conflit_branch}. Please merge the branch"
                        generateTitle "End. Error: Repository is on a new branch"
                        exit 2

                    elif [[ "${strategy}" =~ "merge-or-fail" ]]; then
                        echo "[ERROR] Merge failed."
                        echo "[WARNING] Repository is in a conflict state!"
                        echo "[INFO] Please solve conflicts and clean working tree manually from ${host} or hard reset to previous commit using '-t <Commit SHA>' option, your local changes will be erased." | fold -s
                        generateTitle "End. Error: Repository is in a conflict state"
                        exit 2
                    
                    else
                        echo "[ERROR] Merge failed."
                        echo "[WARNING] Reseting to last commit and re-applying stashed changes."
                        git reset --hard HEAD~1
                        git stash apply --quiet stash@{0}
                        echo "[INFO] Merge failed, use '-u merge-overwrite' to overwrite remote content or hard reset to previous commit using '-t <Commit SHA>' option, your local changes will be erased." | fold -s
                        generateTitle "End. Error: nothing changed"
                        exit 2
                    fi
                else
                    branch=`git rev-parse --abbrev-ref HEAD`
                    echo "[INFO] Clearing stashes of current branch (${branch}), leaving last 5 stashes" | fold -s
                    for stash in `git stash list | grep "On ${branch}" | awk -F ':' '{print$1}' | tail -n+7 | tail -r`; do
                        if ! git stash drop --quiet "${stash}"
                        then
                            stash_name=`git stash list | grep "On ${branch}" | grep "${stash}"`
                            echo "[WARNING] A stash could not be deleted: ${stash_name}"
                        fi
                    done
                fi

                if [[ "${strategy}" =~ "merge" ]]; then
                    echo "[INFO] Pushing changes"
                    branch=`git rev-parse --abbrev-ref HEAD`
                    with_ssh_key "git push --quiet -u origin ${branch}" "${ssh_key}"
                fi
                cd "${init_folder}"
            done
            ;;
    esac
done
OPTIND=1
while getopts "${optstring}" arg; do
    case "${arg}" in
        i) #Show git log -> To have the commits sha1
            generateTitle "Informations"
            for folder in ${repositories}; do
                cd $folder
                generateTitle "Tracked files ${folder}"
                git ls-tree --full-tree -r --name-only HEAD
                generateTitle "Last ${OPTARG} commits activity ${folder}"
                git --no-pager log -n ${OPTARG} --graph                
                generateTitle "Git status ${folder}"
                git status
                cd "${init_folder}"
            done
            ;;
    esac
done
shift "$((OPTIND-1))"
generateTitle "End (success)"
