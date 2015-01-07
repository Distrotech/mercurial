  $ hg init a
  $ cd a
  $ echo 'root' >root
  $ hg add root
  $ hg commit -d '0 0' -m "Adding root node"

  $ echo 'a' >a
  $ hg add a
  $ hg branch a
  marked working directory as branch a
  (branches are permanent and global, did you want a bookmark?)
  $ hg commit -d '1 0' -m "Adding a branch"

  $ hg branch q
  marked working directory as branch q
  (branches are permanent and global, did you want a bookmark?)
  $ echo 'aa' >a
  $ hg branch -C
  reset working directory to branch a
  $ hg commit -d '2 0' -m "Adding to a branch"

  $ hg update -C 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo 'b' >b
  $ hg add b
  $ hg branch b
  marked working directory as branch b
  (branches are permanent and global, did you want a bookmark?)
  $ hg commit -d '2 0' -m "Adding b branch"

  $ echo 'bh1' >bh1
  $ hg add bh1
  $ hg commit -d '3 0' -m "Adding b branch head 1"

  $ hg update -C 2
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo 'bh2' >bh2
  $ hg add bh2
  $ hg commit -d '4 0' -m "Adding b branch head 2"

  $ echo 'c' >c
  $ hg add c
  $ hg branch c
  marked working directory as branch c
  (branches are permanent and global, did you want a bookmark?)
  $ hg commit -d '5 0' -m "Adding c branch"

reserved names

  $ hg branch tip
  abort: the name 'tip' is reserved
  [255]
  $ hg branch null
  abort: the name 'null' is reserved
  [255]
  $ hg branch .
  abort: the name '.' is reserved
  [255]

invalid characters

  $ hg branch 'foo:bar'
  abort: ':' cannot be used in a name
  [255]

  $ hg branch 'foo
  > bar'
  abort: '\n' cannot be used in a name
  [255]

trailing or leading spaces should be stripped before testing duplicates

  $ hg branch 'b '
  abort: a branch of the same name already exists
  (use 'hg update' to switch to it)
  [255]

  $ hg branch ' b'
  abort: a branch of the same name already exists
  (use 'hg update' to switch to it)
  [255]

verify update will accept invalid legacy branch names

  $ hg init test-invalid-branch-name
  $ cd test-invalid-branch-name
  $ hg pull -u "$TESTDIR"/bundles/test-invalid-branch-name.hg
  pulling from *test-invalid-branch-name.hg (glob)
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 3 changes to 2 files
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg update '"colon:test"'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd ..

  $ echo 'd' >d
  $ hg add d
  $ hg branch 'a branch name much longer than the default justification used by branches'
  marked working directory as branch a branch name much longer than the default justification used by branches
  (branches are permanent and global, did you want a bookmark?)
  $ hg commit -d '6 0' -m "Adding d branch"

  $ hg branches
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  b                              4:aee39cd168d0
  c                              6:589736a22561 (inactive)
  a                              5:d8cbc61dbaa6 (inactive)
  default                        0:19709c5a4e75 (inactive)

-------

  $ hg branches -a
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  b                              4:aee39cd168d0

--- Branch a

  $ hg log -b a
  changeset:   5:d8cbc61dbaa6
  branch:      a
  parent:      2:881fe2b92ad0
  user:        test
  date:        Thu Jan 01 00:00:04 1970 +0000
  summary:     Adding b branch head 2
  
  changeset:   2:881fe2b92ad0
  branch:      a
  user:        test
  date:        Thu Jan 01 00:00:02 1970 +0000
  summary:     Adding to a branch
  
  changeset:   1:dd6b440dd85a
  branch:      a
  user:        test
  date:        Thu Jan 01 00:00:01 1970 +0000
  summary:     Adding a branch
  

---- Branch b

  $ hg log -b b
  changeset:   4:aee39cd168d0
  branch:      b
  user:        test
  date:        Thu Jan 01 00:00:03 1970 +0000
  summary:     Adding b branch head 1
  
  changeset:   3:ac22033332d1
  branch:      b
  parent:      0:19709c5a4e75
  user:        test
  date:        Thu Jan 01 00:00:02 1970 +0000
  summary:     Adding b branch
  

---- going to test branch closing

  $ hg branches
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  b                              4:aee39cd168d0
  c                              6:589736a22561 (inactive)
  a                              5:d8cbc61dbaa6 (inactive)
  default                        0:19709c5a4e75 (inactive)
  $ hg up -C b
  2 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ echo 'xxx1' >> b
  $ hg commit -d '7 0' -m 'adding cset to branch b'
  $ hg up -C aee39cd168d0
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 'xxx2' >> b
  $ hg commit -d '8 0' -m 'adding head to branch b'
  created new head
  $ echo 'xxx3' >> b
  $ hg commit -d '9 0' -m 'adding another cset to branch b'
  $ hg branches
  b                             10:bfbe841b666e
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  c                              6:589736a22561 (inactive)
  a                              5:d8cbc61dbaa6 (inactive)
  default                        0:19709c5a4e75 (inactive)
  $ hg heads --closed
  changeset:   10:bfbe841b666e
  branch:      b
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     adding another cset to branch b
  
  changeset:   8:eebb944467c9
  branch:      b
  parent:      4:aee39cd168d0
  user:        test
  date:        Thu Jan 01 00:00:07 1970 +0000
  summary:     adding cset to branch b
  
  changeset:   7:10ff5895aa57
  branch:      a branch name much longer than the default justification used by branches
  user:        test
  date:        Thu Jan 01 00:00:06 1970 +0000
  summary:     Adding d branch
  
  changeset:   6:589736a22561
  branch:      c
  user:        test
  date:        Thu Jan 01 00:00:05 1970 +0000
  summary:     Adding c branch
  
  changeset:   5:d8cbc61dbaa6
  branch:      a
  parent:      2:881fe2b92ad0
  user:        test
  date:        Thu Jan 01 00:00:04 1970 +0000
  summary:     Adding b branch head 2
  
  changeset:   0:19709c5a4e75
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Adding root node
  
  $ hg heads
  changeset:   10:bfbe841b666e
  branch:      b
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     adding another cset to branch b
  
  changeset:   8:eebb944467c9
  branch:      b
  parent:      4:aee39cd168d0
  user:        test
  date:        Thu Jan 01 00:00:07 1970 +0000
  summary:     adding cset to branch b
  
  changeset:   7:10ff5895aa57
  branch:      a branch name much longer than the default justification used by branches
  user:        test
  date:        Thu Jan 01 00:00:06 1970 +0000
  summary:     Adding d branch
  
  changeset:   6:589736a22561
  branch:      c
  user:        test
  date:        Thu Jan 01 00:00:05 1970 +0000
  summary:     Adding c branch
  
  changeset:   5:d8cbc61dbaa6
  branch:      a
  parent:      2:881fe2b92ad0
  user:        test
  date:        Thu Jan 01 00:00:04 1970 +0000
  summary:     Adding b branch head 2
  
  changeset:   0:19709c5a4e75
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Adding root node
  
  $ hg commit -d '9 0' --close-branch -m 'prune bad branch'
  $ hg branches -a
  b                              8:eebb944467c9
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  $ hg up -C b
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg commit -d '9 0' --close-branch -m 'close this part branch too'
  $ hg commit -d '9 0' --close-branch -m 're-closing this branch'
  abort: can only close branch heads
  [255]

  $ hg log -r tip --debug
  changeset:   12:e3d49c0575d8fc2cb1cd6859c747c14f5f6d499f
  branch:      b
  tag:         tip
  phase:       draft
  parent:      8:eebb944467c9fb9651ed232aeaf31b3c0a7fc6c1
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    8:6f9ed32d2b310e391a4f107d5f0f071df785bfee
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  extra:       branch=b
  extra:       close=1
  description:
  close this part branch too
  
  
--- b branch should be inactive

  $ hg branches
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  c                              6:589736a22561 (inactive)
  a                              5:d8cbc61dbaa6 (inactive)
  default                        0:19709c5a4e75 (inactive)
  $ hg branches -c
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  b                             12:e3d49c0575d8 (closed)
  c                              6:589736a22561 (inactive)
  a                              5:d8cbc61dbaa6 (inactive)
  default                        0:19709c5a4e75 (inactive)
  $ hg branches -a
  a branch name much longer than the default justification used by branches 7:10ff5895aa57
  $ hg branches -q
  a branch name much longer than the default justification used by branches
  c
  a
  default
  $ hg heads b
  no open branch heads found on branches b
  [1]
  $ hg heads --closed b
  changeset:   12:e3d49c0575d8
  branch:      b
  tag:         tip
  parent:      8:eebb944467c9
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     close this part branch too
  
  changeset:   11:d3f163457ebf
  branch:      b
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     prune bad branch
  
  $ echo 'xxx4' >> b
  $ hg commit -d '9 0' -m 'reopen branch with a change'
  reopening closed branch head 12

--- branch b is back in action

  $ hg branches -a
  b                             13:e23b5505d1ad
  a branch name much longer than the default justification used by branches 7:10ff5895aa57

---- test heads listings

  $ hg heads
  changeset:   13:e23b5505d1ad
  branch:      b
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     reopen branch with a change
  
  changeset:   7:10ff5895aa57
  branch:      a branch name much longer than the default justification used by branches
  user:        test
  date:        Thu Jan 01 00:00:06 1970 +0000
  summary:     Adding d branch
  
  changeset:   6:589736a22561
  branch:      c
  user:        test
  date:        Thu Jan 01 00:00:05 1970 +0000
  summary:     Adding c branch
  
  changeset:   5:d8cbc61dbaa6
  branch:      a
  parent:      2:881fe2b92ad0
  user:        test
  date:        Thu Jan 01 00:00:04 1970 +0000
  summary:     Adding b branch head 2
  
  changeset:   0:19709c5a4e75
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Adding root node
  

branch default

  $ hg heads default
  changeset:   0:19709c5a4e75
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Adding root node
  

branch a

  $ hg heads a
  changeset:   5:d8cbc61dbaa6
  branch:      a
  parent:      2:881fe2b92ad0
  user:        test
  date:        Thu Jan 01 00:00:04 1970 +0000
  summary:     Adding b branch head 2
  
  $ hg heads --active a
  no open branch heads found on branches a
  [1]

branch b

  $ hg heads b
  changeset:   13:e23b5505d1ad
  branch:      b
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     reopen branch with a change
  
  $ hg heads --closed b
  changeset:   13:e23b5505d1ad
  branch:      b
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     reopen branch with a change
  
  changeset:   11:d3f163457ebf
  branch:      b
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     prune bad branch
  
default branch colors:

  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > color =
  > [color]
  > mode = ansi
  > EOF

  $ hg up -C c
  3 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ hg commit -d '9 0' --close-branch -m 'reclosing this branch'
  $ hg up -C b
  2 files updated, 0 files merged, 3 files removed, 0 files unresolved
  $ hg branches --color=always
  \x1b[0;32mb\x1b[0m\x1b[0;33m                             13:e23b5505d1ad\x1b[0m (esc)
  \x1b[0;0ma branch name much longer than the default justification used by branches\x1b[0m\x1b[0;33m 7:10ff5895aa57\x1b[0m (esc)
  \x1b[0;0ma\x1b[0m\x1b[0;33m                              5:d8cbc61dbaa6\x1b[0m (inactive) (esc)
  \x1b[0;0mdefault\x1b[0m\x1b[0;33m                        0:19709c5a4e75\x1b[0m (inactive) (esc)

default closed branch color:

  $ hg branches --color=always --closed
  \x1b[0;32mb\x1b[0m\x1b[0;33m                             13:e23b5505d1ad\x1b[0m (esc)
  \x1b[0;0ma branch name much longer than the default justification used by branches\x1b[0m\x1b[0;33m 7:10ff5895aa57\x1b[0m (esc)
  \x1b[0;30;1mc\x1b[0m\x1b[0;33m                             14:f894c25619d3\x1b[0m (closed) (esc)
  \x1b[0;0ma\x1b[0m\x1b[0;33m                              5:d8cbc61dbaa6\x1b[0m (inactive) (esc)
  \x1b[0;0mdefault\x1b[0m\x1b[0;33m                        0:19709c5a4e75\x1b[0m (inactive) (esc)

  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > color =
  > [color]
  > branches.active = green
  > branches.closed = blue
  > branches.current = red
  > branches.inactive = magenta
  > log.changeset = cyan
  > EOF

custom branch colors:

  $ hg branches --color=always
  \x1b[0;31mb\x1b[0m\x1b[0;36m                             13:e23b5505d1ad\x1b[0m (esc)
  \x1b[0;32ma branch name much longer than the default justification used by branches\x1b[0m\x1b[0;36m 7:10ff5895aa57\x1b[0m (esc)
  \x1b[0;35ma\x1b[0m\x1b[0;36m                              5:d8cbc61dbaa6\x1b[0m (inactive) (esc)
  \x1b[0;35mdefault\x1b[0m\x1b[0;36m                        0:19709c5a4e75\x1b[0m (inactive) (esc)

custom closed branch color:

  $ hg branches --color=always --closed
  \x1b[0;31mb\x1b[0m\x1b[0;36m                             13:e23b5505d1ad\x1b[0m (esc)
  \x1b[0;32ma branch name much longer than the default justification used by branches\x1b[0m\x1b[0;36m 7:10ff5895aa57\x1b[0m (esc)
  \x1b[0;34mc\x1b[0m\x1b[0;36m                             14:f894c25619d3\x1b[0m (closed) (esc)
  \x1b[0;35ma\x1b[0m\x1b[0;36m                              5:d8cbc61dbaa6\x1b[0m (inactive) (esc)
  \x1b[0;35mdefault\x1b[0m\x1b[0;36m                        0:19709c5a4e75\x1b[0m (inactive) (esc)

template output:

  $ hg branches -Tjson --closed
  [
   {
    "active": true,
    "branch": "b",
    "closed": false,
    "current": true,
    "node": "e23b5505d1ad24aab6f84fd8c7cb8cd8e5e93be0",
    "rev": 13
   },
   {
    "active": true,
    "branch": "a branch name much longer than the default justification used by branches",
    "closed": false,
    "current": false,
    "node": "10ff5895aa5793bd378da574af8cec8ea408d831",
    "rev": 7
   },
   {
    "active": false,
    "branch": "c",
    "closed": true,
    "current": false,
    "node": "f894c25619d3f1484639d81be950e0a07bc6f1f6",
    "rev": 14
   },
   {
    "active": false,
    "branch": "a",
    "closed": false,
    "current": false,
    "node": "d8cbc61dbaa6dc817175d1e301eecb863f280832",
    "rev": 5
   },
   {
    "active": false,
    "branch": "default",
    "closed": false,
    "current": false,
    "node": "19709c5a4e75bf938f8e349aff97438539bb729e",
    "rev": 0
   }
  ]

revision branch name caching implementation

cache creation
  $ rm .hg/cache/rbc-revs-v1
  $ hg debugrevspec 'branch("re:a ")'
  7
  $ [ -f .hg/cache/rbc-revs-v1 ] || echo no file
  no file
recovery from invalid cache file
  $ echo > .hg/cache/rbc-revs-v1
  $ hg debugrevspec 'branch("re:a ")'
  7
cache update NOT fully written from revset
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  68b329da9893e34099c7d8ad5cb9c940  .hg/cache/rbc-revs-v1
recovery from other corruption - extra trailing data
  $ echo >> .hg/cache/rbc-revs-v1
  $ hg debugrevspec 'branch("re:a ")'
  7
cache update NOT fully written from revset
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  e1c06d85ae7b8b032bef47e42e4c08f9  .hg/cache/rbc-revs-v1
lazy update after commit
  $ hg tag tag
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  d0c0166808ee0a1f0e8894915ad363b6  .hg/cache/rbc-revs-v1
  $ hg debugrevspec 'branch("re:a ")'
  7
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  d0c0166808ee0a1f0e8894915ad363b6  .hg/cache/rbc-revs-v1
update after rollback - cache keeps stripped revs until written for other reasons
  $ hg up -qr '.^'
  $ hg rollback -qf
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  d8c2acdc229bf942fde1dfdbe8f9d933  .hg/cache/rbc-revs-v1
  $ hg debugrevspec 'branch("re:a ")'
  7
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  d8c2acdc229bf942fde1dfdbe8f9d933  .hg/cache/rbc-revs-v1
handle history mutations that doesn't change the tip node - this is a problem
with the cache invalidation scheme used by branchmap
  $ hg log -r tip+b -T'{rev}:{node|short} {branch}\n'
  14:f894c25619d3 c
  13:e23b5505d1ad b
  $ hg bundle -q --all bu.hg
  $ hg --config extensions.strip= strip --no-b -qr -1:
  $ hg up -q tip
  $ hg branch
  b
  $ hg branch -q hacked
  $ hg ci --amend -qm 'hacked'
  $ hg pull -q bu.hg -r f894c25619d3
  $ hg log -r tip+b -T'{rev}:{node|short} {branch}\n'
  14:f894c25619d3 c
  12:e3d49c0575d8 b
  $ hg debugrevspec 'branch("hacked")'
  13
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  22424d7e106c894336d9d705b0241bc5  .hg/cache/rbc-revs-v1
cleanup, restore old state
  $ hg --config extensions.strip= strip --no-b -qr -2:
  $ hg pull -q bu.hg
  $ rm bu.hg
  $ hg up -qr tip
  $ hg log -r tip -T'{rev}:{node|short}\n'
  14:f894c25619d3
the cache file do not go back to the old state - it still contains the
now unused 'hacked' branch name)
  $ hg debugrevspec 'branch("re:a ")'
  7
  $ "$TESTDIR/md5sum.py" .hg/cache/rbc-revs-v1
  d8c2acdc229bf942fde1dfdbe8f9d933  .hg/cache/rbc-revs-v1
  $ cat .hg/cache/rbc-names-v1
  default\x00a\x00b\x00c\x00a branch name much longer than the default justification used by branches\x00hacked (no-eol) (esc)

  $ cd ..
