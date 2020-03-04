### git-admin
```
% ./git-admin.sh -h

    Usage: ./git-admin.sh [-h] [-k <SSH Key>] [-c <Git clone URL>] [-b 
<Branch>] 
    [-u <Strategy>] [-a] [-m <Commit msg text> ][-f <Commit msg file>] 
    [-t <Commit hash to reset>] [-i <Number of commits to show>]
    -r <Repository path(s)>

    This script is designed to programatically manage merge, pull and push 
changes from and to a git repository.
        
    The script can't solve merge conflict that already exists before calling 
the script.
    
    Options:

        -h      Print this help message.
       
        -k <Key>    Path to a trusted ssh key to authenticate against the git 
server (push). Required if git authentication is not already working with 
default key.
        
        -c <Url>    URL of the git source. The script will use 'git remote add 
origin URL' if the repo folder doesn't exist and init the repo on master 
branch. Required if the repo folder doesn't exists. Warning, if you declare 
several reposities, the same URL will used for all. Multiple repo values are 
not supported by this feature.
        
        -r <Paths>  Path to managed repository, can be multiple comma 
separated. Only remote 'origin' can be used. Warning make sure all repositories 
exists, multiple repo values are not supported by the git clone feature '-c'. 
Repository path(s) should end with the default git repo folder name after git 
clone. Required.
        
        -b <Branch> Switch to the specified branch or tag. Fail if changed 
files in working tree, please merge changes first.
        
        -u <Strategy>   Update the current branch from and to upstream, can 
adopt 7 strategies. This feature supports multiple repo values !
          
            - 'merge' -> Default merge. Save changes as stash (if-any), apply 
them, commit, pull and push, if pull fails, reset pull and re-apply saved 
changes (leaving the repo in the same state as before calling the script). 
Should exit with code 0. Require a write access to git server.
            
            - 'merge-overwrite' -> Keep local changes. Save changes as stash 
(if-any), apply them, commit, pull and push, if pull fails, reset, pull, 
re-apply saved changes, accept only local changes in the merge, commit and push 
to remote. Should exit with code 0. Require a write access to git server.
           
            - 'merge-or-stash' -> Keep remote changes. Save changes as stash 
(if-any), apply them, commit, pull and push, if pull fails, revert commit and 
pull (your changes will be saved as git stash), exit code 2. Require a write 
access to git server.    
          
            - 'merge-or-branch' -> Merge or create a new remote branch. Save 
changes as stash (if-any), apply them, commit, pull and push, if pull fails, 
create a new branch and push changes to remote (leaving the repository in a new 
branch with exit code 2). Require a write access to git server.
          
            - 'merge-or-fail' -> Merge or leave the reposity in a conflict. 
Warning if there is a conflict. Save changes as stash (if-any) (this step can 
fail, the sctipt will continue without saving the stash), apply them, commit, 
pull and push, if pull fails, will leave the git repositiry in a conflict state 
with exit code 2. Require a write access to git server.
         
            - 'stash' -> Always update from remote. Stash the changes and pull. 
Should exit with code 0. Do not require a write acces to git server.

        -a  Add untracked files to git. To use with '-u <Strategy>'.
        
        -m <Commit msg text>    The text will be used as the fist line of the 
commit message, then the generated name with timestamp and then the file 
content. This can be used with '-f'. To use with '-u <Strategy>'.
        
        -f <Commit msg file>    Specify a commit message from a file. To use 
with '-u <Strategy>'.
        
        -t <CommitSAH1> Hard reset the local branch to the specified commit. 
Multiple repo values are not supported by this feature
        
        -i <Number of commits to show>  Shows tracked files, git status and 
commit history of last N commits.

    Examples : 

        $ ./git-admin.sh -r ~/isrm-portal-conf/ -b stable -u merge -i 5
        Checkout the stable branch, pull changes and show infos of the 
repository (last 5 commits).
        $ './git-admin.sh -r ~/isrm-portal-conf/ -t 00a3a3f'
        Hard reset the repository to the specified commit.
        $ './git-admin.sh -k ~/.ssh/id_rsa2 -c 
git@github.com:mfesiem/msiempy.git -r ./test/msiempy/ -u merge'
        Init a repo and pull (master by default). Use the specified SSH to 
authenticate.

    Return codes : 
    
    1 Other errors
    2 Git merge failed
    3 Syntax mistake
    4 Git reposirtory does't exist and '-c URL' is not set
    5 Repository not set
    6 Can't checkout with unstaged files in working tree
    7 Already in the middle of a merge
    8 Stash could not be saved
    
```