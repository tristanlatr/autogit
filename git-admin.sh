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

usage(){
    generateTitle "Usage"
    echo "Usage: $0 [-h] [-k <Key auth for git repo>] [-c <git remote URL>] (-r <Repositorie(s) path(s)>) [-b <Branch>] [-u <Strategy>] [-t <Commit hash>] [-i <Number of commits to show>]" | fold -s
    echo
    echo "This script is designed to programatically manage merge, pull and push feature on git repository." | fold -s
    echo
    echo -e "\t-h\t\tPrint this help message." | fold -s
    echo -e "\t-k <Key>\tPath to a trusted ssh key to authenticate against the git server (push). Required if git authentication is not already working with default key." | fold -s
    echo -e "\t-c <Url>\tURL of the git source. The script will use 'git remote add origin URL' if the repo folder doesn't exist and init the repo on master branch. Required if the repo folder doesn't exists. Warning, if you declare several reposities, the same URL will used for all. Multiple repo values are not supported by this feature." | fold -s
    echo -e "\t-r <Paths>\tPath to managed repository, can be multiple comma separated. Only remote 'origin' can be used. Warning make sure all repositories exists, multiple repo values are not supported by the git clone feature '-c'. Repository path(s) should end with the default git repo folder name after git clone. Required." | fold -s
    echo -e "\t-b <Branch>\tSwitch to the specified branch or tag. Fail if changed files in working tree, please merge changes first." | fold -s
    echo -e "\t-u <Strategy>\tUpdate the current branch from and to upstream, can adopt 6 strategies. This feature supports multiple repo values !" | fold -s
    echo
    echo -e "\t\t- 'merge' -> save changes as stash, apply them, commit, pull and push, if pull fails, reset pull and re-apply saved changes (leaving the repo in the same state as before calling the script). Require a write access to git server." | fold -s
    echo -e "\t\t- 'merge-overwrite' -> save changes as stash, apply them, commit, pull and push, if pull fails, use git pull --rebase --autostash and merge . Require a write access to git server." | fold -s
    echo -e "\t\t- 'merge-or-branch' -> save changes as stash, apply them, commit, pull and push, if pull fails, create a new branch and push changes to remote. Require a write access to git server." | fold -s
    echo -e "\t\t- 'merge-or-fail' -> save changes as stash, apply them, commit, pull and push, if pull fails, will leave the git repositiry in a conflict state. Require a write access to git server." | fold -s
    echo -e "\t\t- 'merge-no-stash' -> commit, pull and push, if pull fails, will leave the git repositiry in a conflict state. Git stash will fail if your in the midle of a merge, this will skip the git stash step. Require a write access to git server." | fold -s
    echo -e "\t\t- 'merge-or-stash' -> save changes as stash, apply them, commit, pull and push, if pull fails, revert commit and pull (your changes will be saved as git stash) Require a write access to git server." | fold -s    
    echo -e "\t\t- 'stash' -> stash the changes and pull. Do not require a write acces to git server." | fold -s
    echo
    echo -e "\t-a\tAdd untracked files to git. To use with '-u <strategy>'."
    echo -e "\t-t <CommitSAH1>\tHard reset the local branch to the specified commit. Multiple repo values are not supported by this feature" | fold -s
    echo -e "\t-i <Number of commits to show>\tShows informations." | fold -s
    echo
    echo -e "\tExamples : " | fold -s
    echo -e "\t\t$0 -r ~/isrm-portal-conf/ -b stable -u merge -i 5" | fold -s
    echo -e "\t\tCheckout the stable branch, pull changes and show infos of the repository (last 5 commits)." | fold -s
    echo -e "\t\t$0 -r ~/isrm-portal-conf/ -t 00a3a3f" | fold -s
    echo -e "\t\tHard reset the repository to the specified commit." | fold -s
    echo -e "\t\t$0 -k ~/.ssh/id_rsa2 -c git@github.com:mfesiem/msiempy.git -r ./test/msiempy/ -u merge" | fold -s
    echo -e "\t\tInit a repo and pull master by default. Use the specified SSH to authenticate." | fold -s
    echo
    echo -e "\tReturn codes : "
    echo -e "\t\t1 Other errors"
    echo -e "\t\t2 Git pull failed"
    echo -e "\t\t3 Syntax mistake"
    echo -e "\t\t4 Git reposirtory does't exist and -c URL is not set"
    echo -e "\t\t5 Repository not set"
    echo -e "\t\t6 Can't checkout with unstaged files in working tree"
}

git_ssh(){
    return_val=-1
    if [[ ! -z "$2" ]]; then
        echo "[INFO] Using SSH key"
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=no'
        ssh-agent bash -c "ssh-add $2 && $1"
        return_val=$?
        git config core.sshCommand 'ssh -o StrictHostKeyChecking=yes'
    else
        echo "[INFO] SSH key not set"
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
commit_msg_file=""
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
            generateTitle "SSH key set ${ssh_key}"
            ;;
        c)
            git_clone_url=${OPTARG}
            generateTitle "Git clone URL set ${git_clone_url}"
            ;;

        f)
            commit_msg_file=${OPTARG}
            generateTitle "Commit message set ${commit_msg_file}"
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
                    git_ssh "git remote update" "${ssh_key}"
                    git_ssh "git branch -a -vv" "${ssh_key}"
                else
                    if [[ ! -z "${git_clone_url}" ]]; then
                        echo "[INFO] Repository do no exist, initating it."
                        mkdir -p ${folder}
                        cd ${folder}
                        git init
                        git remote add -t master origin ${git_clone_url} 
                        git_ssh "git remote update" "${ssh_key}"
                        git_ssh "git branch -a -vv" "${ssh_key}"
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
                    echo "[ERROR] Unkwown strategy ${strategy} '-u <Strategy>' option argument. Please see $0 '-h' for more infos." | fold -s
                    exit 3
                fi
                # If there is any kind of changes in the working tree
                if [[ -n `git status -s` ]]; then
                    commit_and_stash_name="[git-admin] Changes on ${host} $(date)"

                    if [[ "${git_add_untracked}" = true ]]; then
                        echo "[INFO] Adding untracked files"
                        git add .
                    fi

                    echo "[INFO] Locally changed files:"
                    git status -s

                    if [[ ! "${strategy}" =~ "no-stash" ]];then
                        # If staged or unstaged changes in the tracked files in the working tree
                        if ! git diff-files --quiet -- || ! git diff-index --quiet --cached --exit-code HEAD
                        then
                            echo "[INFO] Saving changes as a git stash, you can apply stash manually from ${host}. 'git stash list' help you determine the stash index (n) of this changes (\"${commit_and_stash_name}\"), then use 'git stash apply stash@{n}'." | fold -s
                            if ! git stash save "${commit_and_stash_name}"
                            then
                                echo "[ERROR] You seem to be in the middle of a merge, you can use '-u merge-no-stash' update strategy to skip the git stash save step. If the merge fail, the git repo will be in a conflict state."
                                exit 2
                            fi

                            if [[ "${strategy}" =~ "merge" ]]; then
                                echo "[INFO] Applying stash in order to merge"
                                git stash apply --quiet stash@{0}
                            fi
                        fi
                    fi

                    # If staged or unstaged changes in the tracked files in the working tree
                    if ! git diff-files --quiet -- || ! git diff-index --quiet --cached --exit-code HEAD
                    then
                        echo "[INFO] Committing changes"
                        if [[ -n "${commit_msg_file}" ]]; then
                            commit_msg_file_text=`cat "${commit_msg_file}"`
                            git commit -a -m "${commit_and_stash_name}" -m "${commit_msg_file_text}"
                        else
                            git commit -a -m "${commit_and_stash_name}"
                        fi
                    fi

                else
                    echo "[INFO] No local changes"
                fi

                echo "[INFO] Merging"
                if ! git_ssh "git pull --no-edit" "${ssh_key}"
                then
                    # No error
                    if [[ "${strategy}" =~ "merge-or-stash" ]]; then
                        echo "[WARNING] Git pull failed. Reseting to last commit."
                        echo "[INFO] Your changes are saved as git stash \"${commit_and_stash_name}\"" | fold -s
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling changes"
                        git_ssh "git pull --no-edit" "${ssh_key}"
                    # Force overwrite
                    # No error
                    # Stash, pull, apply and commit changes.
                    elif [[ "${strategy}" =~ "merge-overwrite" ]]; then
                        echo "[WARNING] Git pull failed. Overwriting remote."
                        echo "[INFO] Reseting"
                        git reset --hard HEAD~1
                        echo "[INFO] Pulling"
                        if ! git_ssh "git pull --no-edit --no-commit" "${ssh_key}"
                        then
                            echo "[INFO] Git pull failed --no-commit"
                        fi
                        echo "[INFO] Apply stash"
                        git stash apply --quiet stash@{0}
                        for changed_file in `git ls-tree --full-tree -r --name-only HEAD`; do
                            echo "[INFO] Overwriting ${changed_file}"
                            git checkout --ours -- ${changed_file}
                            git add ${changed_file}
                        done
                        git commit -a -m "[Overwrite] ${commit_and_stash_name}" -m "${commit_msg_file_text}"

                    elif [[ "${strategy}" =~ "merge-or-branch" ]]; then
                        conflit_branch="$(echo ${commit_and_stash_name} | tr -cd '[:alnum:]')"
                        echo "[WARNING] Git pull failed. Creating a new remote branch ${conflit_branch}"
                        git reset --hard HEAD~1
                        git checkout -b ${conflit_branch}
                        echo "[INFO] Applying stash in order to push to new remote branch"
                        git stash apply --quiet stash@{0}
                        git_ssh "git push --quiet -u origin ${branch}" "${ssh_key}"
                        echo "[INFO] You changes are pushed to remote branch ${conflit_branch}. Please merge the branch"
                        generateTitle "Git status ${folder}"
                        git status
                        generateTitle "End. Warning: Repository is on a new branch"
                        exit 2

                    elif [[ "${strategy}" =~ "no-stash" ]] || [[ "${strategy}" =~ "merge-or-fail" ]]; then
                        echo "[ERROR] Git pull failed."
                        echo "[WARNING] Repository is in a conflict state!"
                        echo "[INFO] Please solve conflicts on the local branch manually from ${host} or hard reset to previous commit using '-t <commitSHA>' option, your local changes will be erased." | fold -s
                        generateTitle "Git status ${folder}"
                        git status
                        generateTitle "End. Error: Repository is in a conflict state"
                        exit 2
                    
                    else
                        echo "[ERROR] Git pull failed."
                        echo "[WARNING] Git pull failed. Reseting to last commit and re-applying stashed changes."
                        git reset --hard HEAD~1
                        git stash apply --quiet stash@{0}
                        echo "[INFO] Please merge the local branch manually from ${host} or hard reset to previous commit using '-t <commitSHA>' option, your local changes will be erased." | fold -s
                        generateTitle "Git status ${folder}"
                        git status
                        generateTitle "End. Warning: nothing changed"
                        exit 2
                    fi
                fi

                if [[ "${strategy}" =~ "merge" ]]; then
                    echo "[INFO] Pushing changes"
                    branch=`git rev-parse --abbrev-ref HEAD`
                    git_ssh "git push --quiet -u origin ${branch}" "${ssh_key}"
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
                generateTitle "Last ${OPTARG} commits activity ${folder}"
                git --no-pager log -n ${OPTARG} --graph
                #git --no-pager log --graph --all --since "$(date -d "${OPTARG} days ago" "+ %Y-%m-%dT%T")"
                generateTitle "Tracked files ${folder}"
                git ls-tree --full-tree -r --name-only HEAD
                generateTitle "Git status ${folder}"
                git status
                cd "${init_folder}"
            done
            ;;
    esac
done
shift "$((OPTIND-1))"

generateTitle "End (success)"
