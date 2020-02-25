#!/bin/bash

### CODE COPIED ###

# menu.sh
# Description: Bash menu generator
# Created by Jamie Cruwys on 21/02/2014.

# Configuration
symbol="*"
paddingSymbol=" "
lineLength=70
charsToOption=1
charsToName=3

function generatePadding() {
    string="";
    for (( i=0; i < $2; i++ )); do
        string+="$1";
    done
    echo "$string";
}

# Generated configs
remainingLength=$(( $lineLength - 2 ));
line=$(generatePadding "${symbol}" "${lineLength}");
toOptionPadding=$(generatePadding "${paddingSymbol}" "${charsToOption}");
toNamePadding=$(generatePadding "$paddingSymbol" "$charsToName");

# generateText (text)
function generateText() {
    totalCharsToPad=$((remainingLength - ${#1}));
    charsToPadEachSide=$((totalCharsToPad / 2));
    padding=$(generatePadding "$paddingSymbol" "$charsToPadEachSide");
    totalChars=$(( ${#symbol} + ${#padding} + ${#1} + ${#padding} + ${#symbol} ));
    if [[ ${totalChars} < ${lineLength} ]]; then
        echo "${symbol}${padding}${1}${padding}${paddingSymbol}${symbol}";
    else
        echo "${symbol}${padding}${1}${padding}${symbol}";
    fi
}

function generateSubTitle() {  
    echo "$line"
    generateText "$1"
    echo "$line"
}

# generateTitle (title)
function generateTitle() {  
    echo "$line"
    generateText ""
    generateText "$1"
    generateText ""
    echo "$line"
}
### END CODE COPIED ###


#Setting bash strict mode. See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t,'

#FUNCTIONS

#updateFromMaster() {
    #See https://stackoverflow.com/questions/1214906/how-do-i-merge-a-sub-directory-in-git
    #git pull --no-edit --no-commit
    #git merge -s ours --no-commit origin/${_REMOTE_BRANCH} ${_LOCAL_BRANCH}
    #git rm --quiet -rf .
    #git read-tree --prefix=${_GIT_SUBDIR} -u origin/${_REMOTE_BRANCH}:${_GIT_SUBDIR}
    #echo none
#}

usage(){
    generateTitle "Usage"
        echo "Usage: $0 [-h] [-k <Key auth for git repo>] [-c <git remote URL>] (-r <Repositorie(s) path(s)>) [-b <Branch>] [-u] [-t <Commit hash>] [-i <Number of commits to show>]" 1>&2
    echo
    echo "This script is designed to manage versionning git repository."
    echo "VERY IMPORTANT. Arguments should be passed to the script in the same order they are listed in this"
    echo "message to avoid unexpected behaviours."
    echo
    echo -e "\t-h\t\tPrint this help message."
    echo -e "\t-k <Key>\tPath to a trusted ssh key to authenticate against the git server (push). Required if git authentication is not already working with default key."
    echo -e "\t-c <Url>\tURL of the git source. The script will use 'git remote add origin URL' if the repo folder doesn't exist and init the repo on master branch. Required if the repo folder doesn't exists. Warning, if you declare several reposities, the same URL will used for all. Multiple repo values are not supported by this feature."
    echo -e "\t-r <Paths>\tPath to managed repository, can be multiple comma separated. Warning make sure all repositories exists., multiple repo values are not supported by the git clone feature '-c'. Repository path(s) should end with the default git repo folder name after git clone Required."
    echo -e "\t-b <Branch>\tSwitch to the specified branch or tag."
    echo -e "\t\t\tBranch must already exist in the local repository copy (run git checkout origin/branch from the host before)."
    echo -e "\t-u\t\tUpdate the current branch from and to upstream. (commit, pull and push). This feature supports multiple repo values !"
    echo -e "\t-t <CommitSAH1>\tHard reset the FIRST local branch to the specified commit.  Multiple repo values are not supported by this feature"
    echo -e "\t-i <Number of commits to show>\tShows informations."
    echo
    echo -e "\tExamples : "
    echo -e "\t\t$0 -r ~/isrm-portal-conf/ -b stable -u -i 5"
    echo -e "\t\tCheckout the stable branch, pull changes and show infos of the repository (last 5 commits)."
    echo -e "\t\t$0 -r ~/isrm-portal-conf/ -b stable -t 00a3a3f"
    echo -e "\t\tCheckout the stable branch and hard reset the repository to the specified commit."
    echo -e "\t\t$0 -k ~/.ssh/id_rsa2 -c git@github.com:mfesiem/msiempy.git -r ./test/msiempy/ -u "
    echo -e "\t\tInit a repo and pull master by default. Use the specified SSH to authenticate."
    echo
    echo -e "\tError codes : "
    echo -e "\t\t1 Repository not set"
    echo -e "\t\t2 Git pull failed"
    echo -e "\t\t3 Syntax mistake"
    echo -e "\t\t4 Git reposirtory does't exist and -c URL is not set"
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
repositoryIsSet=false
repositories=()
ssh_key=""
git_clone_url=""
init_folder=`pwd`

generateTitle "Administration on ${host}"
generateSubTitle "PWD ${init_folder}"

while getopts ":hk:c:r:b:ut:i:" arg; do
    case "${arg}" in
        h) #Print help
            usage
            ;;
        k)
            ssh_key=${OPTARG}
            generateSubTitle "SSH key set ${ssh_key}"
            ;;
        c)
            git_clone_url=${OPTARG}
            generateSubTitle "Git clone URL set ${git_clone_url}"
            ;;
        r)
            generateTitle "Repositorie(s)"
            
            repositories=${OPTARG}
            for folder in ${repositories}; do
                
                generateSubTitle "$folder"

                if [[ -d "$folder" ]]; then
                    cd $folder
                    git_ssh "git remote update" "${ssh_key}"
                    git_ssh "git branch -a -vv" "${ssh_key}"
                else
                    if [[ ! -z "${git_clone_url}" ]]; then
                        
                        cd `dirname ${folder}`
                        mkdir `basename ${folder}`
                        cd `basename ${folder}`

                        git init
                        git remote add -t master origin ${git_clone_url} 

                        git_ssh "git remote update" "${ssh_key}"
                        git_ssh "git branch -a -vv" "${ssh_key}"
                    else
                        echo "[ERROR] Git reposirtory does't exist and -c URL is not set. Please make sure arguments are in the correct order."
                        exit 4
                    fi
                fi
                cd "${init_folder}"
            done
            repositoryIsSet=true
            ;;
        
        b)
            generateTitle "Checkout(s)"
            if [ "$repositoryIsSet" = true ]; then
                for folder in ${repositories}; do
                    
                    generateSubTitle "Checkout ${folder}"
                    cd $folder
                    git checkout ${OPTARG}
                    cd "${init_folder}"
                done
            else
                echo "[ERROR] You need to set the repository to checkout a branch"
                exit 1
            fi
            ;;

        u) #Update
            generateTitle "Updates(s)"
            if [ "$repositoryIsSet" = true ]; then
                for folder in ${repositories}; do
                    
                    cd $folder
                    generateSubTitle "Update ${folder}"
                    local_changes=0
                    diff=`git diff`
                    if [[ -n "$diff" ]]; then
                        echo "[INFO] Locally changed files:"
                        echo "$diff"
                        git commit -a -m "Local changes - automatic commit $(date)"
                        local_changes=1
                    fi

                    set +e
                    echo "[INFO] Pulling changes"
                    git_ssh "git pull" "${ssh_key}" #--no-edit is commented on TOR linux box cause git version doesn't support it
                    if [[ ! $? -eq 0 ]]; then
                        echo "[ERROR] Git pull failed: please read error output. Select a branch with '-b' if you init the git repo. You can merge manually or hard reset to previous commit using '-t' option, your local changes will be erased."
                        exit 2
                    fi
                    set -e

                    if [[ $local_changes -eq 1 ]]; then
                        echo "[INFO] Pushing changes"
                        git_ssh "git push" "${ssh_key}"
                    fi
                    cd "${init_folder}"
                done
            else
                echo "[ERROR] You need to set the repository to update"
                exit 1
            fi
            ;;
        t)
            generateTitle "Reseting to previous commit"
            if [ "$repositoryIsSet" = true ]; then

                for folder in ${repositories}; do
                    
                    echo "[INFO] Reseting ${folder} to ${OPTARG} commit"
                    cd $folder
                    git reset --hard ${OPTARG}
                    cd "${init_folder}"
                    break
                done
                
            else
                echo "[ERROR] You need to set the repository to reset branch"
                exit 1
            fi
            ;;
        i) #Show git log -> To have the commits sha1
            generateTitle "Informations"
            if [ "$repositoryIsSet" = true ]; then

                for folder in ${repositories}; do
                    
                    cd $folder
                    generateSubTitle "Last ${OPTARG} commits activity ${folder}"
                    git --no-pager log -n ${OPTARG} --graph
                    #git --no-pager log --graph --all --since "$(date -d "${OPTARG} days ago" "+ %Y-%m-%dT%T")"
                    generateSubTitle "Tracked files ${folder}"
                    git ls-tree --full-tree -r --name-only HEAD
                    generateSubTitle "Git status ${folder}"
                    git status
                    cd "${init_folder}"
                done

            else
                echo "[ERROR] You need to set the repository to show information"
                exit 1
            fi
            ;;
        *)
            generateTitle "Syntax mistake"
            echo "[ERROR] You made a syntax mistake calling the script."
            exit 3
    esac
done
shift $((OPTIND-1))
generateTitle "End (success)"