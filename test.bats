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

  # Test status ok
  assert_success

  # Run autogit on repo 1
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

  # Test status ok
  assert_success

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  assert [ "$readme1" = "$readme2" ]

}

@test "Test both edited no conflicts" {

  # Writing a first line to readme file 1
  echo "New file in repository" > $HERE/testing-1/test-autogit/new_file.md

  # Writing a second line to readme file 2
  echo "New line in readme" >> $HERE/testing-2/test-autogit/README.md

  # Run autogit on repo 1, with add untracked flag
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -a
  # Test status ok
  assert_success

  # Run autogit on repo 2, will pull new file
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  # Test status ok
  assert_success

  new_file1=`cat $HERE/testing-1/test-autogit/new_file.md`
  new_file2=`cat $HERE/testing-2/test-autogit/new_file.md`

  # Test merge ok
  assert [ "$new_file1" = "$new_file2" ]

  # Run autogit on repo 1 to update readme
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
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
  # Test status ok
  assert_success

  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 2. will fail and roll back to previous state
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge

  # Test status merge failed with exit code 2
  assert_failure 2

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`
  # Test merge rolled back ok
  assert [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Test readme files didn't change
  assert [ "$readme1_after_merge" = "$readme1_before_merge" ]
}

@test "Test conflicts with merge-overwrite" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md

  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

  # Test status ok
  assert_success

  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 2. will overwrite server version
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-overwrite

  # Test status ok
  assert_success

  # Test the output contains 
  # [[ "$output" =~ "Merge failed. Reseting to last commit" ]]
  # [[ "$output" =~ "Overwriting conflicted files with local changes" ]]

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files on local repo 2 are the same
  assert [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 1, to refresh changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

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
  # Test status ok
  assert_success

  # Run autogit on repo 2. Will stash local version and update with upstream
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-stash

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
  # Test status ok
  assert_success

  # Run autogit on repo 2. Will stry to merge and leave the repo in a conflict
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-fail

  # Test status merge failed
  assert_failure 2

  # Run autogit on repo 2. Will stry to merge and leave the repo in a conflict
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge

  # Test status in a middle of a merge
  assert_failure 7
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
  # Test status ok
  assert_success

  # Run autogit on repo 2. Will try to merge and leave the repo in a new branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-branch
  # echo $output >&3
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
  # echo $output >&3
  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Test readme files the same before and after merge
  assert [ "$readme1_after_merge" = "$readme1_before_merge" ]

  # Run autogit on repo2 to swich to master branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b master -u merge
  # echo $output >&3
  # Test status merge ok
  assert_success

  readme2_after_swicth_branch_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test the file haven't change on master
  assert [ "$readme1_before_merge" = "$readme2_after_swicth_branch_merge" ]

  # Come back to new branch and test file content
  # Run autogit on repo2 to reswich to new branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b $new_branch -u merge
  # echo $output >&3
  # Test status merge failed
  assert_success

  readme2_end=`cat $HERE/testing-2/test-autogit/README.md`

  # Test the file haven't change on master
  assert [ "$readme2_before_merge" = "$readme2_end" ]
}

@test "Test checkout" {
  # Tests checkout inmpossible because of changed files

  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  
  $HERE/autogit.sh -r $HERE/testing-1/test-autogit -b another_branch
  
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
}

@test "Test show informations" {
  # Test -i flag
}

@test "Test different remote" {
  
}

@test "Test fatal error" {
  
}

@test "Test merge-overwrite fails then merge-or-branch success" {
  
}
