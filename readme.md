### git-admin
```
**********************************************************************
*                     git-admin on Tristans-MBP                      *
**********************************************************************
**********************************************************************
*                               Usage                                *
**********************************************************************
Usage: ./git-admin.sh [-h] [-k <Key auth for git repo>] [-c <git remote URL>] 
(-r <Repositorie(s) path(s)>) [-b <Branch>] [-u <Strategy>] [-t <Commit hash>] 
[-i <Number of commits to show>]

This script is designed to programatically manage merge, pull and push feature 
on git repository.

	-h		Print this help message.
	-k <Key>	Path to a trusted ssh key to authenticate against the 
git server (push). Required if git authentication is not already working with 
default key.
	-c <Url>	URL of the git source. The script will use 'git remote 
add origin URL' if the repo folder doesn't exist and init the repo on master 
branch. Required if the repo folder doesn't exists. Warning, if you declare 
several reposities, the same URL will used for all. Multiple repo values are 
not supported by this feature.
	-r <Paths>	Path to managed repository, can be multiple comma 
separated. Warning make sure all repositories exists., multiple repo values are 
not supported by the git clone feature '-c'. Repository path(s) should end with 
the default git repo folder name after git clone Required.
	-b <Branch>	Switch to the specified branch or tag.
			Branch must already exist in the local repository copy 
(run git checkout origin/branch from the host before).
	-u <Strategy>	Update the current branch from and to upstream, can 
adopt 3 strategies. This feature supports multiple repo values !
		'merge' -> commit, pull and push. Fail if merge fail. Require 
valid git server authentication.
		'stash' -> stash the changes and pull.
		'merge-or-stash' -> stash, commit, pull and push, if pull fails 
revert commit and pull. Require valid git server authentication.
		'add-untracked-merge' -> git add untracked files, and merge.
		'add-untracked-stash' -> git add untracked files, stash the 
changes and pull.
		'add-untracked-merge-or-stash' -> git add untracked files, 
merge or stash changes. Require valid git server authentication.
	-t <CommitSAH1>	Hard reset the FIRST local branch to the specified 
commit.  Multiple repo values are not supported by this feature
	-i <Number of commits to show>	Shows informations.

	Examples : 
		./git-admin.sh -r ~/isrm-portal-conf/ -b stable -u merge -i 5
		Checkout the stable branch, pull changes and show infos of the 
repository (last 5 commits).
		./git-admin.sh -r ~/isrm-portal-conf/ -b stable -t 00a3a3f
		Checkout the stable branch and hard reset the repository to the 
specified commit.
		./git-admin.sh -k ~/.ssh/id_rsa2 -c 
git@github.com:mfesiem/msiempy.git -r ./test/msiempy/ -u merge-or-stash 
		Init a repo and pull master by default. Use the specified SSH 
to authenticate.

	Return codes : 
		1 Other errors
		2 Git pull failed
		3 Syntax mistake
		4 Git reposirtory does't exist and -c URL is not set
		5 Repository not set
		6 Can't checkout with unstaged files in working tree
```