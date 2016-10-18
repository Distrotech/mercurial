# Copyright 2010-2011 Fog Creek Software
# Copyright 2010-2011 Unity Technologies
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

'''remote largefile store; the base class for wirestore'''
from __future__ import absolute_import

from mercurial.i18n import _

from mercurial import (
    error,
    util,
    wireproto,
)

from . import (
    basestore,
    lfutil,
    localstore,
)

urlerr = util.urlerr
urlreq = util.urlreq

class remotestore(basestore.basestore):
    '''a largefile store accessed over a network'''
    def __init__(self, ui, repo, url):
        super(remotestore, self).__init__(ui, repo, url)
        self._lstore = localstore.localstore(self.ui, self.repo, self.repo)

    def put(self, source, hash):
        if self.sendfile(source, hash):
            raise error.Abort(
                _('remotestore: could not put %s to remote store %s')
                % (source, util.hidepassword(self.url)))
        self.ui.debug(
            _('remotestore: put %s to remote store %s\n')
            % (source, util.hidepassword(self.url)))

    def exists(self, hashes):
        return dict((h, s == 0) for (h, s) in # dict-from-generator
                    self._stat(hashes).iteritems())

    def sendfile(self, filename, hash):
        self.ui.debug('remotestore: sendfile(%s, %s)\n' % (filename, hash))
        try:
            with lfutil.httpsendfile(self.ui, filename) as fd:
                return self._put(hash, fd)
        except IOError as e:
            raise error.Abort(
                _('remotestore: could not open file %s: %s')
                % (filename, str(e)))

    def _getfile(self, tmpfile, filename, hash):
        try:
            chunks = self._get(hash)
        except urlerr.httperror as e:
            # 401s get converted to error.Aborts; everything else is fine being
            # turned into a StoreError
            raise basestore.StoreError(filename, hash, self.url, str(e))
        except urlerr.urlerror as e:
            # This usually indicates a connection problem, so don't
            # keep trying with the other files... they will probably
            # all fail too.
            raise error.Abort('%s: %s' %
                             (util.hidepassword(self.url), e.reason))
        except IOError as e:
            raise basestore.StoreError(filename, hash, self.url, str(e))

        return lfutil.copyandhash(chunks, tmpfile)

    def _hashesavailablelocally(self, hashes):
        existslocallymap = self._lstore.exists(hashes)
        localhashes = [hash for hash in hashes if existslocallymap[hash]]
        return localhashes

    def _verifyfiles(self, contents, filestocheck):
        failed = False
        expectedhashes = [expectedhash
                          for cset, filename, expectedhash in filestocheck]
        localhashes = self._hashesavailablelocally(expectedhashes)
        stats = self._stat([expectedhash for expectedhash in expectedhashes
                            if expectedhash not in localhashes])

        for cset, filename, expectedhash in filestocheck:
            if expectedhash in localhashes:
                filetocheck = (cset, filename, expectedhash)
                verifyresult = self._lstore._verifyfiles(contents,
                                                         [filetocheck])
                if verifyresult:
                    failed = True
            else:
                stat = stats[expectedhash]
                if stat:
                    if stat == 1:
                        self.ui.warn(
                            _('changeset %s: %s: contents differ\n')
                            % (cset, filename))
                        failed = True
                    elif stat == 2:
                        self.ui.warn(
                            _('changeset %s: %s missing\n')
                            % (cset, filename))
                        failed = True
                    else:
                        raise RuntimeError('verify failed: unexpected response '
                                           'from statlfile (%r)' % stat)
        return failed

    def batch(self):
        '''Support for remote batching.'''
        return wireproto.remotebatch(self)

    def _put(self, hash, fd):
        '''Put file with the given hash in the remote store.'''
        raise NotImplementedError('abstract method')

    def _get(self, hash):
        '''Get a iterator for content with the given hash.'''
        raise NotImplementedError('abstract method')

    def _stat(self, hashes):
        '''Get information about availability of files specified by
        hashes in the remote store. Return dictionary mapping hashes
        to return code where 0 means that file is available, other
        values if not.'''
        raise NotImplementedError('abstract method')
