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
}

@test "Test simple pull" {

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
  # Tests that no commit get pushed with -o option
}

@test "Test repo init" {
  # Test -c flag
}

@test "Test stash" {
  # test stash strategy
}

@test "Test reset" {
  # Test -t flag
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

@test "Test show informations" {
  # Test -i flag
}

@test "Test different remote" {
  
}

@test "Test fatal error" {

}

@test "Test merge-overwrite fails because of wrong manual work then merge-or-branch success" {

  # Commit some changes on repo 2 
  echo "Some comments in readme" >> $HERE/testing-2/test-autogit/README.md
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  echo $output
  # Test status ok
  assert_success

  # Silumate wrong manual local work on the repo 1
  # It's wrong because branch is in a conflict and not beeing addressed by merging with remote branch
  cd $HERE/testing-1/test-autogit
  echo -e "Replace the content with updated version all in one. \nLike a manual upgrade of config files or something..." > README.md
  git commit -a -m "Important update"
  git status
  cd $HERE

  # Simulate normal work on repo 1, then call autogit
  echo "Some important comments in readme" >> $HERE/testing-1/test-autogit/README.md
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  echo $output
  # Test status merge failed
  assert_failure 2

  readme1_before_merge_overwrite=`cat $HERE/testing-1/test-autogit/readme.md`

  # Try with merge-overwrite
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge-overwrite
  echo $output
  # Test status merge failed
  assert_failure 2

  readme1_after_merge_overwrite=`cat $HERE/testing-1/test-autogit/readme.md`

  # Test git merge --abort actually rolled back changes
  assert [ "$readme1_before_merge_overwrite" = "$readme1_after_merge_overwrite" ]

  # Create new branch
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge-or-branch
  echo $output
  assert_success
  assert_output --partial '[WARNING] Repository is on a new branch'

  readme1_after_merge_or_branch=`cat $HERE/testing-1/test-autogit/readme.md`

  # Test everything normal
  assert [ "$readme1_before_merge_overwrite" = "$readme1_after_merge_overwrite" ]

  # Get branch name
  cd $HERE/testing-1/test-autogit
  branch=`git branch | grep "*" | awk -F ' ' '{print$2}'`
  cd $HERE

  # Checkout the new branch and refresh changes, nedd to use merge-or-stash to discard initial commit
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-stash -b ${branch}
  echo $output

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files the same accros repos
  assert [ "$readme1_before_merge_overwrite" = "$readme2_after_merge" ]

}
