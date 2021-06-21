#!/usr/bin/env bats

# autogit test script

HERE=$BATS_TEST_DIRNAME

# Load BATS script libraries
load "$HERE/bats-support/load.bash"
load "$HERE/bats-assert/load.bash"

function setup {

  # Setup new testing repos under testing-1 and testing-2
  rm -rf $HERE/test-autogit.git || true
  rm -rf $HERE/test-autogit || true
  rm -rf $HERE/testing-1 || true
  rm -rf $HERE/testing-2 || true

  git init --bare $HERE/test-autogit.git
  git clone $HERE/test-autogit.git
  cd test-autogit
  # Setup git required options
  git config user.email "autogit@mail.com" 
  git config user.name "autogit"
  echo "Testing autogit" > README.md
  git add README.md
  git commit -m "Initial commit with readme"
  git push -u origin master
  cd ..
  rm -rf ./test-autogit/
  mkdir testing-1
  mkdir testing-2
  cd testing-1
  git clone ../test-autogit.git
  cd test-autogit
  # Setup git required options
  git config user.email "autogit@mail.com" 
  git config user.name "autogit"
  cd ../..
  cd testing-2
  git clone ../test-autogit.git
  cd test-autogit
  # Setup git required options
  git config user.email "autogit@mail.com" 
  git config user.name "autogit"
  cd ../..
}

function teardown {
  rm -rf $HERE/test-autogit.git
  rm -rf $HERE/test-autogit
  rm -rf $HERE/testing-1
  rm -rf $HERE/testing-2
  rm -rf $HERE/new-remote
}

@test "Test simple pull with merge strategy" {

  # Writing and pushing a second line to readme file 1
  cd $HERE/testing-1/test-autogit
  echo "Second line to file" >> README.md
  
  git commit -a -m "Testing second line to file"
  git push -u origin master
  cd $HERE

  # Run autogit on repo 2
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  echo $output
  
  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  assert [ "$readme1" = "$readme2" ]

}

@test "Test simple push" {

  # Writing a second line to readme file 2
  echo "Second line to file" >> $HERE/testing-2/test-autogit/README.md
  
  # Run autogit on repo 2
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  echo $output
  
  # Test status ok
  assert_success

  # Run autogit on repo 1
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output

  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  assert [ "$readme1" = "$readme2" ]

}

@test "Test pull strategy" {

  # Writing a first line to readme file 1
  echo "New file in repository" > $HERE/testing-1/test-autogit/new_file.md

  # Writing a second line to readme file 2
  echo "New line in readme" >> $HERE/testing-2/test-autogit/README.md

  # Run autogit on repo 1, with add untracked flag
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -a
  echo $output
  # Test status ok
  assert_success

  # Run autogit on repo 2, will pull new file
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u pull
  echo $output
  # Test status ok
  assert_success

  new_file1=`cat $HERE/testing-1/test-autogit/new_file.md`
  new_file2=`cat $HERE/testing-2/test-autogit/new_file.md`

  # Test pull ok
  assert [ "$new_file1" = "$new_file2" ]

  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Run autogit on repo 1 to update readme, shoud not do anything since data has not been pushed
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`

  # Test that the merge did not pull any data
  assert [ "$readme1" = "$readme1_before_merge" ]

}

@test "Test conflicts with pull strategy" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 2. will fail and roll back to previous state
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u pull
  echo $output
  # Test status merge failed with exit code 2
  assert_failure 2

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`
  # Test merge rolled back ok
  assert [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u pull
  echo $output
  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Test readme files didn't change
  assert [ "$readme1_after_merge" = "$readme1_before_merge" ]
}

@test "Test switch branches" {
  # Test -b flag
  
  # generate 10 new branches in testing repo 1
  for i in {1..10}; do
      # Writing a line to readme file 1
      echo "New line $i in readme" >> $HERE/testing-1/test-autogit/README.md
      run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge 
      echo $output
      assert_success
      # create a new branch
      run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -b "branch$i"
      echo $output
      assert_success
  done
  
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -b branch4
  echo $output
  assert_success
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b branch4
  echo $output
  assert_success

  readme1_branch4=`cat $HERE/testing-1/test-autogit/README.md`
  readme2_branch4=`cat $HERE/testing-2/test-autogit/README.md`
  
  assert [ "$readme1_branch4" = "$readme2_branch4" ]

  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -b branch9
  echo $output
  assert_success
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b branch9
  echo $output
  assert_success

  readme1_branch9=`cat $HERE/testing-1/test-autogit/README.md`
  readme2_branch9=`cat $HERE/testing-2/test-autogit/README.md`
  
  assert [ "$readme1_branch9" = "$readme2_branch9" ]
  
}

@test "Test multiple remote" {
  # Creating a new  'fork'
  mkdir new-remote
  cd new-remote
  git clone $HERE/test-autogit.git --bare

  # adding the remote to the local repos
  cd $HERE/testing-1/test-autogit
  git remote add new $HERE/new-remote/test-autogit.git
  cd $HERE/testing-2/test-autogit
  git remote add new $HERE/new-remote/test-autogit.git
  cd $HERE

  readme1_init=`cat $HERE/testing-1/test-autogit/README.md`

  # Switch to new branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -x new -b newb
  echo $output
  
  # Test status ok
  assert_success

  # Writing a second line to readme file 2
  echo "Second line to file" >> $HERE/testing-2/test-autogit/README.md
  
  # Run autogit on repo 2 with new remote, push to branch newb
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge -x new
  echo $output
  
  # Test status ok
  assert_success

  # Run autogit on repo 1 with origin remote
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -x origin -b newb
  echo $output

  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test that remote origin do not contained the infos, since it was push to new remote
  assert [ "$readme1" != "$readme2" ]
  assert [ "$readme1_init" = "$readme1" ]

  # Run autogit on repo 1 with new remote
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -x new -b newb
  echo $output

  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge OK
  assert [ "$readme1" = "$readme2" ]

}

@test "Test both changed with add untracked no conflicts" {

  # Writing a first line to readme file 1
  echo "New file in repository" > $HERE/testing-1/test-autogit/new_file.md

  # Writing a second line to readme file 2
  echo "New line in readme" >> $HERE/testing-2/test-autogit/README.md

  # Run autogit on repo 1, with add untracked flag
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -a
  echo $output
  # Test status ok
  assert_success

  # Run autogit on repo 2, will pull new file
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  new_file1=`cat $HERE/testing-1/test-autogit/new_file.md`
  new_file2=`cat $HERE/testing-2/test-autogit/new_file.md`

  # Test merge ok
  assert [ "$new_file1" = "$new_file2" ]

  # Run autogit on repo 1 to update readme
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  assert [ "$readme1" = "$readme2" ]

}

@test "Test both changed with add untracked no conflicts multiple repositories" {

  # Writing a first line to readme file 1
  echo "New file in repository" > $HERE/testing-1/test-autogit/new_file.md

  # Writing a second line to readme file 2
  echo "New line in readme" >> $HERE/testing-2/test-autogit/README.md

  # Run autogit on repo 1 and 2 at the same time, with add untracked flag
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit,$HERE/testing-2/test-autogit -u merge -a
  echo $output
  # Test status ok
  assert_success

  new_file1=`cat $HERE/testing-1/test-autogit/new_file.md`
  new_file2=`cat $HERE/testing-2/test-autogit/new_file.md`

  # Test merge ok
  assert [ "$new_file1" = "$new_file2" ]

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test that the changes in readme2 did not propagate yet to readme1
  assert [ "$readme1" != "$readme2" ]

  # Run autogit on repo 1 and 2 at the same time, again, (will update repo1 only)
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit,$HERE/testing-2/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  assert [ "$readme1" = "$readme2" ]

}

@test "Test conflicts with default merge" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 2. will fail and roll back to previous state
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  echo $output
  # Test status merge failed with exit code 2
  assert_failure 2

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`
  # Test merge rolled back ok
  assert [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Test readme files didn't change
  assert [ "$readme1_after_merge" = "$readme1_before_merge" ]
}

@test "Test conflicts with merge-overwrite" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md

  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 2. will overwrite server version
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-overwrite
  echo $output
  # Test status ok
  assert_success

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files on local repo 2 are the same
  assert [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 1, to refresh changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output

  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Test readme files the same accros repos
  assert [ "$readme1_after_merge" = "$readme2_after_merge" ]

}

@test "Test conflicts with merge-or-stash" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`
  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Run autogit on repo 2. Will stash local version and update with upstream
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-stash
  echo $output
  # Test the output contains 
  # [[ "$output" =~ "Merge failed. Reseting to last commit" ]]
  # [[ "$output" =~ "Your changes are saved as git stash" ]]
  
  # Test status merge failed
  assert_success

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files on local repo 2 changed for the repo1 version
  assert [ "$readme1_before_merge" = "$readme2_after_merge" ]

  # Run autogit repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success
  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Test readme files the same accros repos
  assert [ "$readme1_after_merge" = "$readme1_before_merge" ]

}

@test "Test conflicts with merge-or-fail" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`
  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Run autogit on repo 2. Will try to merge
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-fail
  echo $output
  # Test status merge failed
  assert_failure 2

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files are unchanged
  assert [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 2.
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  echo $output

  # Test status failure
  assert_failure 2
}

@test "Test conflicts with merge-or-branch" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`
  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Run autogit on repo 2. Will try to merge and leave the repo in a new branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-branch
  echo $output
  # Test status ok
  assert_success

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test the file haven't change
  assert [ "$readme2_before_merge" = "$readme2_after_merge" ]

  cd $HERE/testing-2/test-autogit/
  new_branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
  # Test the branch name contains "autogit"
  [[ "${new_branch}" =~ "autogit" ]]
  cd $HERE

  # Run autogit on repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # echo $output >&3
  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Test readme files the same before and after merge
  assert [ "$readme1_after_merge" = "$readme1_before_merge" ]

  # Run autogit on repo2 to swich to master branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b master -u merge
  echo $output
  # Test status merge ok
  assert_success

  readme2_after_swicth_branch_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test the file haven't change on master
  assert [ "$readme1_before_merge" = "$readme2_after_swicth_branch_merge" ]

  # Come back to new branch and test file content
  # Run autogit on repo2 to reswich to new branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b $new_branch -u merge
  echo $output
  # Test status merge failed
  assert_success

  readme2_end=`cat $HERE/testing-2/test-autogit/README.md`

  # Test the file haven't change on master
  assert [ "$readme2_before_merge" = "$readme2_end" ]
}

@test "Test checkout impossible because of changed files" {
  # Tests checkout inmpossible because of changed files

  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -b another_branch
  echo $output
  assert_failure 6
  
}

@test "Test read-only" {
  # Tests that no commit or new branches  gets pushed with -o option
  
  # Writing a first line to readme file 1
  echo "New file in repository" > $HERE/testing-1/test-autogit/new_file.md

  # Writing a second line to readme file 2
  echo "New line in readme" >> $HERE/testing-2/test-autogit/README.md

  # Run autogit on repo 1, with add untracked flag
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -a
  echo $output
  # Test status ok
  assert_success

  # Run autogit on repo 2, will pull new file only, merge with local copy BUT do no push
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge -o
  echo $output
  # Test status ok
  assert_success

  new_file1=`cat $HERE/testing-1/test-autogit/new_file.md`
  new_file2=`cat $HERE/testing-2/test-autogit/new_file.md`

  # Test merge ok
  assert [ "$new_file1" = "$new_file2" ]

  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Run autogit on repo 1 to update readme, 
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # See that the readme is not updated cause of read-only
  assert [ "$readme1_before_merge" = "$readme1_after_merge" ]

  # create a new branch on repo2
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -o -b new_branch_42
  echo $output
  # Test status ok
  assert_success
  assert_output --partial '[INFO] Creating a new branch new_branch_42'

  # try to checkout the new branch on repo1
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -o -b new_branch_42
  echo $output
  # Test status ok
  assert_success
  assert_output --partial '[INFO] Creating a new branch new_branch_42'

  # create a new branch on repo2
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b new_branch_43
  echo $output
  # Test status ok
  assert_success
  assert_output --partial '[INFO] Creating a new branch new_branch_43'

  # checkout the new branch on repo1
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -o -b new_branch_43
  echo $output
  # Test status ok
  assert_success
  assert_output --partial '[INFO] Checking out remote branch new_branch_43'

}

@test "Test repo init" {
  # Test -c flag
  
  run $HERE//autogit.sh -c "https://github.com/mfesiem/msiempy.git" -r ./msiempy/ -b develop
  echo $output
  # Test status ok
  assert_success
  cd msiempy
  git checkout main
  cd ..
  rm -rf msiempy

}

@test "Test clear stashes" {
  # Test -s flag
  
  # generate 10 new stashes in testing repo 1
  
  for i in {1..10}; do
      # Writing a line to readme file 1
      echo "New line $i in readme" >> $HERE/testing-1/test-autogit/README.md
      run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge 
      assert_success
  done
  
  cd $HERE/testing-1/test-autogit
  # Test stashes are beeing created
  assert [ `git stash list | wc -l` = "10" ]
  
  # Test 5 stash are left
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -s 5 
  echo $output
  assert_success
  assert [ `git stash list | wc -l` = "5" ]
  
  # Test 5 stash are still left
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -s 5
  echo $output 
  assert_success
  assert [ `git stash list | wc -l` = "5" ]
  
  # Test all stash dropped
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -s 0 
  echo $output
  assert_success
  assert [ -z `git stash list` ]
  
}


@test "Test merge-overwrite fails because of manual commit on repo then merge-or-branch success" {

  # Commit some changes on repo 2 
  echo "Some comments in readme" >> $HERE/testing-2/test-autogit/README.md
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Silumate manual local work on the repo 1: calling 'git commit' only.
  # It's problematic because the branch is in a conflict and not beeing addressed by merging with remote branch manually!
  cd $HERE/testing-1/test-autogit
  echo -e "Replace the content with updated version all in one. \nLike a manual upgrade of config files or something..." > README.md
  git commit -a -m "Important update"
  git status
  cd $HERE

  # Simulate normal/automated work on repo 1, then call autogit
  echo "Some important comments in readme" >> $HERE/testing-1/test-autogit/README.md
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status merge failed
  assert_failure 2
  
  readme1_before_merge_overwrite=`cat $HERE/testing-1/test-autogit/README.md`

  # Try with merge-overwrite
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge-overwrite
  echo $output
  # Test status merge failed because '-u merge-overwrite' only tries to look one 
  # commit behind, and if that commit is also in conflict with remote, then it fails. 
  assert_failure 2

  readme1_after_merge_overwrite=`cat $HERE/testing-1/test-autogit/README.md`

  # Test git merge --abort actually rolled back changes
  assert [ "$readme1_before_merge_overwrite" = "$readme1_after_merge_overwrite" ]

  # Create new branch
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge-or-branch
  echo $output
  assert_success
  assert_output --partial '[WARNING] Repository is on a new branch'

  readme1_after_merge_or_branch=`cat $HERE/testing-1/test-autogit/README.md`

  # Test everything normal
  assert [ "$readme1_before_merge_overwrite" = "$readme1_after_merge_overwrite" ]

  # Get branch name
  cd $HERE/testing-1/test-autogit
  branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
  cd $HERE

  # Checkout the new branch on the other working copy just to make sure
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b ${branch}
  echo $output
  assert_success

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files the same accros repos
  assert [ "$readme1_before_merge_overwrite" = "$readme2_after_merge" ]

}

@test "Test show information" {

  # Commit some changes on repo 2 
  echo "Some comments in readme" >> $HERE/testing-2/test-autogit/README.md
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge -m "Commentsblabla"
  echo $output
  # Test status ok
  assert_success

  # Show information
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -i 5
  assert_success
  assert_output --partial "Commentsblabla"
}
