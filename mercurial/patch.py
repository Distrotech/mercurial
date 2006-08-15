# patch.py - patch file parsing routines
#
# Copyright 2006 Brendan Cully <brendan@kublai.com>
#
# This software may be used and distributed according to the terms
# of the GNU General Public License, incorporated herein by reference.

from demandload import demandload
from i18n import gettext as _
from node import *
demandload(globals(), "cmdutil mdiff util")
demandload(globals(), "cStringIO email.Parser os re shutil sys tempfile")

def extract(ui, fileobj):
    '''extract patch from data read from fileobj.

    patch can be normal patch or contained in email message.

    return tuple (filename, message, user, date). any item in returned
    tuple can be None.  if filename is None, fileobj did not contain
    patch. caller must unlink filename when done.'''

    # attempt to detect the start of a patch
    # (this heuristic is borrowed from quilt)
    diffre = re.compile(r'^(?:Index:[ \t]|diff[ \t]|RCS file: |' +
                        'retrieving revision [0-9]+(\.[0-9]+)*$|' +
                        '(---|\*\*\*)[ \t])', re.MULTILINE)

    fd, tmpname = tempfile.mkstemp(prefix='hg-patch-')
    tmpfp = os.fdopen(fd, 'w')
    try:
        hgpatch = False

        msg = email.Parser.Parser().parse(fileobj)

        message = msg['Subject']
        user = msg['From']
        # should try to parse msg['Date']
        date = None

        if message:
            message = message.replace('\n\t', ' ')
            ui.debug('Subject: %s\n' % message)
        if user:
            ui.debug('From: %s\n' % user)
        diffs_seen = 0
        ok_types = ('text/plain', 'text/x-diff', 'text/x-patch')

        for part in msg.walk():
            content_type = part.get_content_type()
            ui.debug('Content-Type: %s\n' % content_type)
            if content_type not in ok_types:
                continue
            payload = part.get_payload(decode=True)
            m = diffre.search(payload)
            if m:
                ui.debug(_('found patch at byte %d\n') % m.start(0))
                diffs_seen += 1
                cfp = cStringIO.StringIO()
                if message:
                    cfp.write(message)
                    cfp.write('\n')
                for line in payload[:m.start(0)].splitlines():
                    if line.startswith('# HG changeset patch'):
                        ui.debug(_('patch generated by hg export\n'))
                        hgpatch = True
                        # drop earlier commit message content
                        cfp.seek(0)
                        cfp.truncate()
                    elif hgpatch:
                        if line.startswith('# User '):
                            user = line[7:]
                            ui.debug('From: %s\n' % user)
                        elif line.startswith("# Date "):
                            date = line[7:]
                    if not line.startswith('# '):
                        cfp.write(line)
                        cfp.write('\n')
                message = cfp.getvalue()
                if tmpfp:
                    tmpfp.write(payload)
                    if not payload.endswith('\n'):
                        tmpfp.write('\n')
            elif not diffs_seen and message and content_type == 'text/plain':
                message += '\n' + payload
    except:
        tmpfp.close()
        os.unlink(tmpname)
        raise

    tmpfp.close()
    if not diffs_seen:
        os.unlink(tmpname)
        return None, message, user, date
    return tmpname, message, user, date

def readgitpatch(patchname):
    """extract git-style metadata about patches from <patchname>"""
    class gitpatch:
        "op is one of ADD, DELETE, RENAME, MODIFY or COPY"
        def __init__(self, path):
            self.path = path
            self.oldpath = None
            self.mode = None
            self.op = 'MODIFY'
            self.copymod = False
            self.lineno = 0
    
    # Filter patch for git information
    gitre = re.compile('diff --git a/(.*) b/(.*)')
    pf = file(patchname)
    gp = None
    gitpatches = []
    # Can have a git patch with only metadata, causing patch to complain
    dopatch = False

    lineno = 0
    for line in pf:
        lineno += 1
        if line.startswith('diff --git'):
            m = gitre.match(line)
            if m:
                if gp:
                    gitpatches.append(gp)
                src, dst = m.group(1,2)
                gp = gitpatch(dst)
                gp.lineno = lineno
        elif gp:
            if line.startswith('--- '):
                if gp.op in ('COPY', 'RENAME'):
                    gp.copymod = True
                    dopatch = 'filter'
                gitpatches.append(gp)
                gp = None
                if not dopatch:
                    dopatch = True
                continue
            if line.startswith('rename from '):
                gp.op = 'RENAME'
                gp.oldpath = line[12:].rstrip()
            elif line.startswith('rename to '):
                gp.path = line[10:].rstrip()
            elif line.startswith('copy from '):
                gp.op = 'COPY'
                gp.oldpath = line[10:].rstrip()
            elif line.startswith('copy to '):
                gp.path = line[8:].rstrip()
            elif line.startswith('deleted file'):
                gp.op = 'DELETE'
            elif line.startswith('new file mode '):
                gp.op = 'ADD'
                gp.mode = int(line.rstrip()[-3:], 8)
            elif line.startswith('new mode '):
                gp.mode = int(line.rstrip()[-3:], 8)
    if gp:
        gitpatches.append(gp)

    if not gitpatches:
        dopatch = True

    return (dopatch, gitpatches)

def dogitpatch(patchname, gitpatches):
    """Preprocess git patch so that vanilla patch can handle it"""
    pf = file(patchname)
    pfline = 1

    fd, patchname = tempfile.mkstemp(prefix='hg-patch-')
    tmpfp = os.fdopen(fd, 'w')

    try:
        for i in range(len(gitpatches)):
            p = gitpatches[i]
            if not p.copymod:
                continue

            if os.path.exists(p.path):
                raise util.Abort(_("cannot create %s: destination already exists") %
                            p.path)

            (src, dst) = [os.path.join(os.getcwd(), n)
                          for n in (p.oldpath, p.path)]

            targetdir = os.path.dirname(dst)
            if not os.path.isdir(targetdir):
                os.makedirs(targetdir)
            try:
                shutil.copyfile(src, dst)
                shutil.copymode(src, dst)
            except shutil.Error, inst:
                raise util.Abort(str(inst))

            # rewrite patch hunk
            while pfline < p.lineno:
                tmpfp.write(pf.readline())
                pfline += 1
            tmpfp.write('diff --git a/%s b/%s\n' % (p.path, p.path))
            line = pf.readline()
            pfline += 1
            while not line.startswith('--- a/'):
                tmpfp.write(line)
                line = pf.readline()
                pfline += 1
            tmpfp.write('--- a/%s\n' % p.path)

        line = pf.readline()
        while line:
            tmpfp.write(line)
            line = pf.readline()
    except:
        tmpfp.close()
        os.unlink(patchname)
        raise

    tmpfp.close()
    return patchname

def patch(patchname, ui, strip=1, cwd=None):
    """apply the patch <patchname> to the working directory.
    a list of patched files is returned"""

    (dopatch, gitpatches) = readgitpatch(patchname)

    files = {}
    fuzz = False
    if dopatch:
        if dopatch == 'filter':
            patchname = dogitpatch(patchname, gitpatches)
        patcher = util.find_in_path('gpatch', os.environ.get('PATH', ''), 'patch')
        args = []
        if cwd:
            args.append('-d %s' % util.shellquote(cwd))
        fp = os.popen('%s %s -p%d < %s' % (patcher, ' '.join(args), strip,
                                           util.shellquote(patchname)))

        if dopatch == 'filter':
            False and os.unlink(patchname)

        for line in fp:
            line = line.rstrip()
            ui.note(line + '\n')
            if line.startswith('patching file '):
                pf = util.parse_patch_output(line)
                printed_file = False
                files.setdefault(pf, (None, None))
            elif line.find('with fuzz') >= 0:
                fuzz = True
                if not printed_file:
                    ui.warn(pf + '\n')
                    printed_file = True
                ui.warn(line + '\n')
            elif line.find('saving rejects to file') >= 0:
                ui.warn(line + '\n')
            elif line.find('FAILED') >= 0:
                if not printed_file:
                    ui.warn(pf + '\n')
                    printed_file = True
                ui.warn(line + '\n')
            
        code = fp.close()
        if code:
            raise util.Abort(_("patch command failed: %s") %
                             util.explain_exit(code)[0])

    for gp in gitpatches:
        files[gp.path] = (gp.op, gp)

    return (files, fuzz)

def diff(repo, node1=None, node2=None, files=None, match=util.always,
         fp=None, changes=None, opts=None):
    '''print diff of changes to files between two nodes, or node and
    working directory.

    if node1 is None, use first dirstate parent instead.
    if node2 is None, compare node1 with working directory.'''

    if opts is None:
        opts = mdiff.defaultopts
    if fp is None:
        fp = repo.ui

    if not node1:
        node1 = repo.dirstate.parents()[0]
    # reading the data for node1 early allows it to play nicely
    # with repo.status and the revlog cache.
    change = repo.changelog.read(node1)
    mmap = repo.manifest.read(change[0])
    date1 = util.datestr(change[2])

    if not changes:
        changes = repo.status(node1, node2, files, match=match)[:5]
    modified, added, removed, deleted, unknown = changes
    if files:
        def filterfiles(filters):
            l = [x for x in filters if x in files]

            for t in files:
                if not t.endswith("/"):
                    t += "/"
                l += [x for x in filters if x.startswith(t)]
            return l

        modified, added, removed = map(filterfiles, (modified, added, removed))

    if not modified and not added and not removed:
        return

    if node2:
        change = repo.changelog.read(node2)
        mmap2 = repo.manifest.read(change[0])
        _date2 = util.datestr(change[2])
        def date2(f):
            return _date2
        def read(f):
            return repo.file(f).read(mmap2[f])
        def renamed(f):
            src = repo.file(f).renamed(mmap2[f])
            return src and src[0] or None
    else:
        tz = util.makedate()[1]
        _date2 = util.datestr()
        def date2(f):
            try:
                return util.datestr((os.lstat(repo.wjoin(f)).st_mtime, tz))
            except OSError, err:
                if err.errno != errno.ENOENT: raise
                return _date2
        def read(f):
            return repo.wread(f)
        def renamed(f):
            return repo.dirstate.copies.get(f)

    if repo.ui.quiet:
        r = None
    else:
        hexfunc = repo.ui.verbose and hex or short
        r = [hexfunc(node) for node in [node1, node2] if node]

    if opts.git:
        copied = {}
        for f in added:
            src = renamed(f)
            if src:
                copied[f] = src
        srcs = [x[1] for x in copied.items()]

    all = modified + added + removed
    all.sort()
    for f in all:
        to = None
        tn = None
        dodiff = True
        if f in mmap:
            to = repo.file(f).read(mmap[f])
        if f not in removed:
            tn = read(f)
        if opts.git:
            def gitmode(x):
                return x and '100755' or '100644'
            def addmodehdr(header, omode, nmode):
                if omode != nmode:
                    header.append('old mode %s\n' % omode)
                    header.append('new mode %s\n' % nmode)

            a, b = f, f
            header = []
            if f in added:
                if node2:
                    mode = gitmode(mmap2.execf(f))
                else:
                    mode = gitmode(util.is_exec(repo.wjoin(f), None))
                if f in copied:
                    a = copied[f]
                    omode = gitmode(mmap.execf(a))
                    addmodehdr(header, omode, mode)
                    op = a in removed and 'rename' or 'copy'
                    header.append('%s from %s\n' % (op, a))
                    header.append('%s to %s\n' % (op, f))
                    to = repo.file(a).read(mmap[a])
                else:
                    header.append('new file mode %s\n' % mode)
            elif f in removed:
                if f in srcs:
                    dodiff = False
                else:
                    mode = gitmode(mmap.execf(f))
                    header.append('deleted file mode %s\n' % mode)
            else:
                omode = gitmode(mmap.execf(f))
                nmode = gitmode(util.is_exec(repo.wjoin(f), mmap.execf(f)))
                addmodehdr(header, omode, nmode)
            r = None
            if dodiff:
                header.insert(0, 'diff --git a/%s b/%s\n' % (a, b))
                fp.write(''.join(header))
        if dodiff:
            fp.write(mdiff.unidiff(to, date1, tn, date2(f), f, r, opts=opts))

def export(repo, revs, template='hg-%h.patch', fp=None, switch_parent=False,
           opts=None):
    '''export changesets as hg patches.'''

    total = len(revs)
    revwidth = max(map(len, revs))

    def single(node, seqno, fp):
        parents = [p for p in repo.changelog.parents(node) if p != nullid]
        if switch_parent:
            parents.reverse()
        prev = (parents and parents[0]) or nullid
        change = repo.changelog.read(node)

        if not fp:
            fp = cmdutil.make_file(repo, template, node, total=total,
                                   seqno=seqno, revwidth=revwidth)
        if fp not in (sys.stdout, repo.ui):
            repo.ui.note("%s\n" % fp.name)

        fp.write("# HG changeset patch\n")
        fp.write("# User %s\n" % change[1])
        fp.write("# Date %d %d\n" % change[2])
        fp.write("# Node ID %s\n" % hex(node))
        fp.write("# Parent  %s\n" % hex(prev))
        if len(parents) > 1:
            fp.write("# Parent  %s\n" % hex(parents[1]))
        fp.write(change[4].rstrip())
        fp.write("\n\n")

        diff(repo, prev, node, fp=fp, opts=opts)
        if fp not in (sys.stdout, repo.ui):
            fp.close()

    for seqno, cset in enumerate(revs):
        single(cset, seqno, fp)
