  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > largefiles =
  > share =
  > graphlog =
  > [largefiles]
  > minsize = 0.5
  > patterns = **.dat
  > EOF

"lfconvert" works
  $ hg init bigfile-repo
  $ cd bigfile-repo
  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > largefiles = !
  > EOF
  $ mkdir sub
  $ dd if=/dev/zero bs=1k count=256 > large 2> /dev/null
  $ echo normal > normal1
  $ echo alsonormal > sub/normal2
  $ dd if=/dev/zero bs=1k count=10 > sub/maybelarge.dat 2> /dev/null
  $ hg addremove
  adding large
  adding normal1
  adding sub/maybelarge.dat
  adding sub/normal2
  $ hg commit -m"add large, normal1" large normal1
  $ hg commit -m"add sub/*" sub
  $ [ -d .hg/largefiles ] && echo fail || echo pass
  pass
  $ cd ..
  $ hg lfconvert --size 0.2 bigfile-repo largefiles-repo
  initializing destination largefiles-repo

"lfconvert" converts content correctly
  $ cd largefiles-repo
  $ hg up
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved
  getting changed largefiles
  2 largefiles updated, 0 removed
  $ hg locate
  .hglf/large
  .hglf/sub/maybelarge.dat
  normal1
  sub/normal2
  $ cat normal1
  normal
  $ cat sub/normal2
  alsonormal
  $ sha1sum large sub/maybelarge.dat
  2e000fa7e85759c7f4c254d4d9c33ef481e459a7  large
  34e163be8e43c5631d8b92e9c43ab0bf0fa62b9c  sub/maybelarge.dat

"lfconvert" adds 'largefiles' to .hg/requires.
  $ cat .hg/requires
  largefiles
  revlogv1
  fncache
  store
  dotencode

"lfconvert" includes a newline at the end of the standin files.
  $ cat .hglf/large .hglf/sub/maybelarge.dat
  2e000fa7e85759c7f4c254d4d9c33ef481e459a7
  34e163be8e43c5631d8b92e9c43ab0bf0fa62b9c

add another largefile to the new largefiles repo
  $ dd if=/dev/zero bs=1k count=1k > anotherlarge 2> /dev/null
  $ hg add --lfsize=1 anotherlarge
  $ hg commit -m "add anotherlarge (should be a largefile)"
  $ cat .hglf/large .hglf/anotherlarge
  2e000fa7e85759c7f4c254d4d9c33ef481e459a7
  3b71f43ff30f4b15b5cd85dd9e95ebc7e84eb5a3
  $ cd ..

add some changesets to rename/remove/merge
  $ cd bigfile-repo
  $ hg mv -q sub stuff
  $ hg commit -m"rename sub/ to stuff/"
  $ hg update -q 1
  $ echo blah >> normal3
  $ echo blah >> sub/normal2
  $ echo blah >> sub/maybelarge.dat
  $ sha1sum sub/maybelarge.dat
  76236b6a2c6102826c61af4297dd738fb3b1de38  sub/maybelarge.dat
  $ hg commit -A -m"add normal3, modify sub/*"
  adding normal3
  created new head
  $ hg rm large normal3
  $ hg commit -q -m"remove large, normal3"
  $ hg merge
  merging sub/maybelarge.dat and stuff/maybelarge.dat to stuff/maybelarge.dat
  warning: $TESTTMP/bigfile-repo/stuff/maybelarge.dat looks like a binary file.
  merging stuff/maybelarge.dat failed!
  merging sub/normal2 and stuff/normal2 to stuff/normal2
  0 files updated, 1 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg update -C .' to abandon
  [1]
  $ hg cat -r . sub/maybelarge.dat > stuff/maybelarge.dat
  $ hg resolve -m stuff/maybelarge.dat
  $ hg commit -m"merge"
  $ hg glog --template "{rev}:{node|short}  {desc|firstline}\n"
  @    5:4884f215abda  merge
  |\
  | o  4:7285f817b77e  remove large, normal3
  | |
  | o  3:67e3892e3534  add normal3, modify sub/*
  | |
  o |  2:c96c8beb5d56  rename sub/ to stuff/
  |/
  o  1:020c65d24e11  add sub/*
  |
  o  0:117b8328f97a  add large, normal1
  
  $ cd ..

lfconvert with rename, merge, and remove
  $ hg lfconvert --size 0.2 bigfile-repo largefiles2-repo
  initializing destination largefiles2-repo
  $ cd largefiles2-repo
  $ hg glog --template "{rev}:{node|short}  {desc|firstline}\n"
  o    5:8e05f5f2b77e  merge
  |\
  | o  4:a5a02de7a8e4  remove large, normal3
  | |
  | o  3:55759520c76f  add normal3, modify sub/*
  | |
  o |  2:261ad3f3f037  rename sub/ to stuff/
  |/
  o  1:334e5237836d  add sub/*
  |
  o  0:d4892ec57ce2  add large, normal1
  
  $ hg locate -r 2
  .hglf/large
  .hglf/stuff/maybelarge.dat
  normal1
  stuff/normal2
  $ hg locate -r 3
  .hglf/large
  .hglf/sub/maybelarge.dat
  normal1
  normal3
  sub/normal2
  $ hg locate -r 4
  .hglf/sub/maybelarge.dat
  normal1
  sub/normal2
  $ hg locate -r 5
  .hglf/stuff/maybelarge.dat
  normal1
  stuff/normal2
  $ hg update
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  getting changed largefiles
  1 largefiles updated, 0 removed
  $ cat stuff/normal2
  alsonormal
  blah
  $ sha1sum stuff/maybelarge.dat
  76236b6a2c6102826c61af4297dd738fb3b1de38  stuff/maybelarge.dat
  $ cat .hglf/stuff/maybelarge.dat
  76236b6a2c6102826c61af4297dd738fb3b1de38
  $ cd ..

"lfconvert" error cases
  $ hg lfconvert http://localhost/foo foo
  abort: http://localhost/foo is not a local Mercurial repo
  [255]
  $ hg lfconvert foo ssh://localhost/foo
  abort: ssh://localhost/foo is not a local Mercurial repo
  [255]
  $ hg lfconvert nosuchrepo foo
  abort: repository nosuchrepo not found!
  [255]
  $ hg share -q -U bigfile-repo shared
  $ echo -n bogus > shared/.hg/sharedpath
  $ hg lfconvert shared foo
  abort: .hg/sharedpath points to nonexistent directory $TESTTMP/bogus!
  [255]
  $ hg lfconvert bigfile-repo largefiles-repo
  initializing destination largefiles-repo
  abort: repository largefiles-repo already exists!
  [255]

Convert back to a normal (non-largefiles) repo
  $ cd largefiles-repo
  $ hg lfconvert --to-normal . ../normal-repo
  initializing destination ../normal-repo
  $ cd ../normal-repo
  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > largefiles = !
  > EOF
  $ hg update
  5 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg locate
  anotherlarge
  large
  normal1
  sub/maybelarge.dat
  sub/normal2
  $ [ -d .hg/largefiles ] && echo fail || echo pass
  pass
