  $ echo "[extensions]" >> $HGRCPATH
  $ echo "mq=" >> $HGRCPATH

  $ echo "[mq]" >> $HGRCPATH
  $ echo "plain=true" >> $HGRCPATH
   strip         strip changesets and all their descendants from the repository
  use "hg -v help mq" to show builtin aliases and global options
  \x1b[0;32;1mA .hgignore\x1b[0m (esc)
  \x1b[0;32;1mA A\x1b[0m (esc)
  \x1b[0;32;1mA B\x1b[0m (esc)
  \x1b[0;32;1mA series\x1b[0m (esc)
  \x1b[0;35;1;4m? flaf\x1b[0m (esc)
  $ rm -f .hg/cache/tags
.hg/cache/tags (pre qpush):
  $ cat .hg/cache/tags
  
.hg/cache/tags (post qpush):
  $ cat .hg/cache/tags
  
  saved backup bundle to $TESTTMP/b/.hg/strip-backup/*-backup.hg (glob)
  patch failed, rejects left in working dir
