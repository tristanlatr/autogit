### autogit: Automatic git updates

This script is designed to programatically update git repositories: pull and push changes. The key feature is that the default merge  strategy is safe as long as your repository is not is the midle of a merge conflict. Safe in the way that if a merge conflict happend during pull, the script will roll back to previous state.

Usage summary: `autogit.sh [-h] [-k <SSH Key>] [-c <Git clone URL>] [-b <Branch>] [-u <Strategy>] [-m <Commit msg text> ][-f <Commit msg file>] [-t <Commit hash to reset>] [-i <Number of commits to show>] [-s <Number of stash to keep>] [-a] [-q] [-x <Remote>] -r <Repository path>,[<Repository path>...]`

`-h`      Print this help message.  

Principal options:

`-r <Path>,[<Path>...]`  Path to managed repository, can be multiple comma separated. Make sure all repositories exists. Required.  
`-k <Key>`    Path to a valid ssh key. Required if git authentication is not already working with default key.  
`-u <Strategy>`   Update the current branch from and to upstream with a defined strategy. This feature supports multiple repo values.
  - `merge` -> **Restore origninal state if conflicts**. Save changes as stash and apply them (if any), commit, pull and push, if pull fails, roll-back changes leaving the repo in the same state as before calling the script. Exit with code `2` if merge failed.
  - `merge-overwrite` -> **Keep local changes if conflicts**. Save changes as stash (if any), commit, pull and push. If pull fails, roll back changes, pull and re-apply saved changes by accepting only local changes (overwrite), commit and push to remote. Warning, the overwrite might fail leaving the repository in a conflict state if you comitted local files. Exit with code `2` if overwrite failed.
  - `merge-or-stash` -> **Keep remote changes if conflicts**. Save changes as stash and apply them (if any), commit, pull and push, if pull fails, revert commit and pull (your changes will be saved as git stash). Exit with code `2` if merge failed. Require a write access to git server.    
  - `merge-or-branch` -> **Create a new remote branch if conflicts**. Save changes as stash (if-any), apply them, commit, pull and push, if pull fails, create a new branch and push changes to remote **leaving the repository in a new branch**. 
  - `merge-or-fail` -> **Leave the reposity as is if conflicts**. Save changes as stash (if-any). Warning: this step can fail, the sctipt will continue without saving the stash, commit, pull and push. If pull fails, leave the git repositiry in a conflict state with exit code `2`.
  - `stash` -> **No conflicts, always discard local changes**. Always update from remote. Stash the changes and pull. Do not require a write acces to git server.  

Automatic update configuration, to use with `-u <Strategy>`:

`-m <Commit msg text>`    Fist line of the commit message.  
`-f <Commit msg file>`    Commit message from a file.  
`-a`  Add all untracked files to git.  
`-x <Remote>`   Use specific git remote to synchronize changes. Origin by default. Applied to all repositories.  
`-o`    Read-only mode. Do not commit or push any changes. Will still pull and merge remote changes into working copy. 

Other features: 

`-t <Commit>` Hard reset the local branch to the specified commit. Multiple repo values are not supported by this feature  
`-i <Number of commits to show>`  Shows tracked files, git status and commit history of last N commits.  
`-b <Branch>` Switch to the specified branch or tag. Exit with code `6` if changed files in working tree, please merge changes first.  
`-s <Number of stashes to keep>`  Clean stashes and keep the N last.  
`-c <Url>`    URL of the git source. If the repo folder doesn't exist, clone it. Multiple git repository values are not supported by this feature.  
`-q`      Be quiet, do not print anything except errors.  

Examples :  
`$ ./autogit.sh -r ~/isrm-portal-conf/ -u merge -i 5`  
Merge changes and show infos of the repository (last 5 commits).  
`$ ./autogit.sh -r ~/isrm-portal-conf/ -t 00a3a3f`  
Hard reset the repository to the specified commit.  
`$ ./autogit.sh -k ~/.ssh/id_rsa2 -c git@github.com:mfesiem/msiempy.git -r ./test/msiempy/ -u merge`  
Init a repo and pull (master by default). Use the specified SSH to authenticate.  

Notes :

This script will generate new stashes whenever called, use `-s` flag to clear stashes.

Return codes : 

`1` Other errors  
`2` Git merge failed  
`3` Syntax mistake  
`4` Git reposirtory does't exist and `-c <URL>` is not set  
`5` Repository not set  
`6` Can't checkout with changed files in working tree  
`7` Already in the middle of a merge  
`8` Stash could not be saved  
 
