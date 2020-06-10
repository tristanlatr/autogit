#!/usr/bin/env bats

# autogit test script

HERE=$BATS_TEST_DIRNAME

function setup {

  # Setup new testing repos under testing-1 and testing-2
  rm -rf $HERE/test-autogit.git || true
  rm -rf $HERE/test-autogit || true
  rm -rf $HERE/testing-1 || true
  rm -rf $HERE/testing-2 || true

  git init --bare $HERE/test-autogit.git
  git clone $HERE/test-autogit.git
  cd test-autogit
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
  cd ..
  cd testing-2
  git clone ../test-autogit.git

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
  [ "$status" -eq 0 ]
  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  [ "$readme1" = "$readme2" ]

}

@test "Test simple push" {

  # Writing a second line to readme file 2
  echo "Second line to file" >> $HERE/testing-2/test-autogit/README.md
  
  # Run autogit on repo 2
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge

  # Test status ok
  [ "$status" -eq 0 ]

  # Run autogit on repo 1
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

  # Test status ok
  [ "$status" -eq 0 ]

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  [ "$readme1" = "$readme2" ]

}

@test "Test both edited no conflicts" {

  # Writing a first line to readme file 1
  echo "New file in repository" > $HERE/testing-1/test-autogit/new_file.md

  # Writing a second line to readme file 2
  echo "New line in readme" >> $HERE/testing-2/test-autogit/README.md

  # Run autogit on repo 1, with add untracked flag
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge -a
  # echo $output >&3
  # Test status ok
  [ "$status" -eq 0 ]

  # Run autogit on repo 2, will pull new file
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge
  # echo $output >&3
  # Test status ok
  [ "$status" -eq 0 ]

  new_file1=`cat $HERE/testing-1/test-autogit/new_file.md`
  new_file2=`cat $HERE/testing-2/test-autogit/new_file.md`

  # Test merge ok
  [ "$new_file1" = "$new_file2" ]

  # Run autogit on repo 1 to update readme
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  # echo $output >&3
  # Test status ok
  [ "$status" -eq 0 ]

  readme1=`cat $HERE/testing-1/test-autogit/README.md`
  readme2=`cat $HERE/testing-2/test-autogit/README.md`

  # Test merge ok
  [ "$readme1" = "$readme2" ]

}

@test "Test conflicts with default merge" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md
  readme1_before_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  # Test status ok
  [ "$status" -eq 0 ]

  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 2. will fail and roll back to previous state
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge

  # Test status merge failed
  [ "$status" -eq 2 ]

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`
  # Test merge rolled back ok
  [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Test readme files didn't change
  [ "$readme1_after_merge" = "$readme1_before_merge" ]
}

@test "Test conflicts with merge-overwrite" {
  # Writing a second line to readme file 1
  echo "New line in readme" >> $HERE/testing-1/test-autogit/README.md

  # Run autogit on repo 1, to push changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

  # Test status ok
  [ "$status" -eq 0 ]

  # Writing a second line to readme file 2
  echo "New conflicting line in readme" >> $HERE/testing-2/test-autogit/README.md

  readme2_before_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Run autogit on repo 2. will overwrite server version
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-overwrite

  # Test the output contains 
  # [[ "$output" =~ "Merge failed. Reseting to last commit" ]]
  # [[ "$output" =~ "Overwriting conflicted files with local changes" ]]

  # echo $output >&3

  # Test status merge failed
  [ "$status" -eq 0 ]

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files on local repo 2 are the same
  [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit on repo 1, to refresh changes
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge

  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`

  # Test readme files the same accros repos
  [ "$readme1_after_merge" = "$readme2_after_merge" ]

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
  [ "$status" -eq 0 ]

  # Run autogit on repo 2. Will stash local version and update with upstream
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-stash

  # Test the output contains 
  # [[ "$output" =~ "Merge failed. Reseting to last commit" ]]
  # [[ "$output" =~ "Your changes are saved as git stash" ]]
  
  # Test status merge failed
  [ "$status" -eq 0 ]

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test readme files on local repo 2 changed for the repo1 version
  [ "$readme1_before_merge" = "$readme2_after_merge" ]

  # Run autogit repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Test readme files the same accros repos
  [ "$readme1_after_merge" = "$readme1_before_merge" ]

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
  [ "$status" -eq 0 ]

  # Run autogit on repo 2. Will stry to merge and leave the repo in a conflict
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-fail

  # Test status merge failed
  [ "$status" -eq 2 ]

  # Run autogit on repo 2. Will stry to merge and leave the repo in a conflict
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge

  # Test status in a middle of a merge
  [ "$status" -eq 7 ]
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
  [ "$status" -eq 0 ]

  # Run autogit on repo 2. Will try to merge and leave the repo in a new branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -u merge-or-branch
  # Test status merge failed
  [ "$status" -eq 0 ]

  readme2_after_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test the file haven't change
  [ "$readme2_before_merge" = "$readme2_after_merge" ]

  # Run autogit repo 1, should not change anything
  run $HERE/autogit.sh -r $HERE/testing-1/test-autogit -u merge
  readme1_after_merge=`cat $HERE/testing-1/test-autogit/README.md`
  # Test readme files the same accros repos
  [ "$readme1_after_merge" = "$readme1_before_merge" ]

  # Run autogit on repo2 to swich to master branch
  run $HERE/autogit.sh -r $HERE/testing-2/test-autogit -b master -u merge
  # Test status merge failed
  [ "$status" -eq 0 ]

  readme2_after_swicth_branch_merge=`cat $HERE/testing-2/test-autogit/README.md`

  # Test the file haven't change on master
  [ "$readme1_before_merge" = "$readme2_after_swicth_branch_merge" ]
}