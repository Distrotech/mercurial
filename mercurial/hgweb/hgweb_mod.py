# hgweb/hgweb_mod.py - Web interface for a repository.
#
# Copyright 21 May 2005 - (c) 2005 Jake Edge <jake@edge2.net>
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

import os
from mercurial import ui, hg, hook, error, encoding, templater, util, repoview
from mercurial.templatefilters import websub
from mercurial.i18n import _
from common import get_stat, ErrorResponse, permhooks, caching
from common import HTTP_OK, HTTP_NOT_MODIFIED, HTTP_BAD_REQUEST
from common import HTTP_NOT_FOUND, HTTP_SERVER_ERROR
from request import wsgirequest
import webcommands, protocol, webutil

perms = {
    'changegroup': 'pull',
    'changegroupsubset': 'pull',
    'getbundle': 'pull',
    'stream_out': 'pull',
    'listkeys': 'pull',
    'unbundle': 'push',
    'pushkey': 'push',
}

## Files of interest
# Used to check if the repository has changed looking at mtime and size of
# theses files. This should probably be relocated a bit higher in core.
foi = [('spath', '00changelog.i'),
       ('spath', 'phaseroots'), # ! phase can change content at the same size
       ('spath', 'obsstore'),
       ('path', 'bookmarks'), # ! bookmark can change content at the same size
      ]

def makebreadcrumb(url, prefix=''):
    '''Return a 'URL breadcrumb' list

    A 'URL breadcrumb' is a list of URL-name pairs,
    corresponding to each of the path items on a URL.
    This can be used to create path navigation entries.
    '''
    if url.endswith('/'):
        url = url[:-1]
    if prefix:
        url = '/' + prefix + url
    relpath = url
    if relpath.startswith('/'):
        relpath = relpath[1:]

    breadcrumb = []
    urlel = url
    pathitems = [''] + relpath.split('/')
    for pathel in reversed(pathitems):
        if not pathel or not urlel:
            break
        breadcrumb.append({'url': urlel, 'name': pathel})
        urlel = os.path.dirname(urlel)
    return reversed(breadcrumb)

class requestcontext(object):
    """Holds state/context for an individual request.

    Servers can be multi-threaded. Holding state on the WSGI application
    is prone to race conditions. Instances of this class exist to hold
    mutable and race-free state for requests.
    """
    def __init__(self, app):
        object.__setattr__(self, 'app', app)
        object.__setattr__(self, 'repo', app.repo)

        object.__setattr__(self, 'archives', ('zip', 'gz', 'bz2'))

        object.__setattr__(self, 'maxchanges',
                           self.configint('web', 'maxchanges', 10))
        object.__setattr__(self, 'stripecount',
                           self.configint('web', 'stripes', 1))
        object.__setattr__(self, 'maxshortchanges',
                           self.configint('web', 'maxshortchanges', 60))
        object.__setattr__(self, 'maxfiles',
                           self.configint('web', 'maxfiles', 10))
        object.__setattr__(self, 'allowpull',
                           self.configbool('web', 'allowpull', True))

    # Proxy unknown reads and writes to the application instance
    # until everything is moved to us.
    def __getattr__(self, name):
        return getattr(self.app, name)

    def __setattr__(self, name, value):
        return setattr(self.app, name, value)

    # Servers are often run by a user different from the repo owner.
    # Trust the settings from the .hg/hgrc files by default.
    def config(self, section, name, default=None, untrusted=True):
        return self.repo.ui.config(section, name, default,
                                   untrusted=untrusted)

    def configbool(self, section, name, default=False, untrusted=True):
        return self.repo.ui.configbool(section, name, default,
                                       untrusted=untrusted)

    def configint(self, section, name, default=None, untrusted=True):
        return self.repo.ui.configint(section, name, default,
                                      untrusted=untrusted)

    def configlist(self, section, name, default=None, untrusted=True):
        return self.repo.ui.configlist(section, name, default,
                                       untrusted=untrusted)

    archivespecs = {
        'bz2': ('application/x-bzip2', 'tbz2', '.tar.bz2', None),
        'gz': ('application/x-gzip', 'tgz', '.tar.gz', None),
        'zip': ('application/zip', 'zip', '.zip', None),
    }

    def archivelist(self, nodeid):
        allowed = self.configlist('web', 'allow_archive')
        for typ, spec in self.archivespecs.iteritems():
            if typ in allowed or self.configbool('web', 'allow%s' % typ):
                yield {'type': typ, 'extension': spec[2], 'node': nodeid}

class hgweb(object):
    """HTTP server for individual repositories.

    Instances of this class serve HTTP responses for a particular
    repository.

    Instances are typically used as WSGI applications.

    Some servers are multi-threaded. On these servers, there may
    be multiple active threads inside __call__.
    """
    def __init__(self, repo, name=None, baseui=None):
        if isinstance(repo, str):
            if baseui:
                u = baseui.copy()
            else:
                u = ui.ui()
            r = hg.repository(u, repo)
        else:
            # we trust caller to give us a private copy
            r = repo

        r = self._getview(r)
        r.ui.setconfig('ui', 'report_untrusted', 'off', 'hgweb')
        r.baseui.setconfig('ui', 'report_untrusted', 'off', 'hgweb')
        r.ui.setconfig('ui', 'nontty', 'true', 'hgweb')
        r.baseui.setconfig('ui', 'nontty', 'true', 'hgweb')
        # displaying bundling progress bar while serving feel wrong and may
        # break some wsgi implementation.
        r.ui.setconfig('progress', 'disable', 'true', 'hgweb')
        r.baseui.setconfig('progress', 'disable', 'true', 'hgweb')
        self.repo = r
        hook.redirect(True)
        self.repostate = None
        self.mtime = -1
        self.reponame = name
        # we use untrusted=False to prevent a repo owner from using
        # web.templates in .hg/hgrc to get access to any file readable
        # by the user running the CGI script
        self.templatepath = self.config('web', 'templates', untrusted=False)
        self.websubtable = webutil.getwebsubs(r)

    # The CGI scripts are often run by a user different from the repo owner.
    # Trust the settings from the .hg/hgrc files by default.
    def config(self, section, name, default=None, untrusted=True):
        return self.repo.ui.config(section, name, default,
                                   untrusted=untrusted)

    def _getview(self, repo):
        """The 'web.view' config controls changeset filter to hgweb. Possible
        values are ``served``, ``visible`` and ``all``. Default is ``served``.
        The ``served`` filter only shows changesets that can be pulled from the
        hgweb instance.  The``visible`` filter includes secret changesets but
        still excludes "hidden" one.

        See the repoview module for details.

        The option has been around undocumented since Mercurial 2.5, but no
        user ever asked about it. So we better keep it undocumented for now."""
        viewconfig = repo.ui.config('web', 'view', 'served',
                                    untrusted=True)
        if viewconfig == 'all':
            return repo.unfiltered()
        elif viewconfig in repoview.filtertable:
            return repo.filtered(viewconfig)
        else:
            return repo.filtered('served')

    def refresh(self):
        repostate = []
        # file of interrests mtime and size
        for meth, fname in foi:
            prefix = getattr(self.repo, meth)
            st = get_stat(prefix, fname)
            repostate.append((st.st_mtime, st.st_size))
        repostate = tuple(repostate)
        # we need to compare file size in addition to mtime to catch
        # changes made less than a second ago
        if repostate != self.repostate:
            r = hg.repository(self.repo.baseui, self.repo.url())
            self.repo = self._getview(r)
            # update these last to avoid threads seeing empty settings
            self.repostate = repostate
            # mtime is needed for ETag
            self.mtime = st.st_mtime

    def run(self):
        """Start a server from CGI environment.

        Modern servers should be using WSGI and should avoid this
        method, if possible.
        """
        if not os.environ.get('GATEWAY_INTERFACE', '').startswith("CGI/1."):
            raise RuntimeError("This function is only intended to be "
                               "called while running as a CGI script.")
        import mercurial.hgweb.wsgicgi as wsgicgi
        wsgicgi.launch(self)

    def __call__(self, env, respond):
        """Run the WSGI application.

        This may be called by multiple threads.
        """
        req = wsgirequest(env, respond)
        return self.run_wsgi(req)

    def run_wsgi(self, req):
        """Internal method to run the WSGI application.

        This is typically only called by Mercurial. External consumers
        should be using instances of this class as the WSGI application.
        """
        self.refresh()
        rctx = requestcontext(self)

        # This state is global across all threads.
        encoding.encoding = rctx.config('web', 'encoding', encoding.encoding)
        rctx.repo.ui.environ = req.env

        # work with CGI variables to create coherent structure
        # use SCRIPT_NAME, PATH_INFO and QUERY_STRING as well as our REPO_NAME

        req.url = req.env['SCRIPT_NAME']
        if not req.url.endswith('/'):
            req.url += '/'
        if 'REPO_NAME' in req.env:
            req.url += req.env['REPO_NAME'] + '/'

        if 'PATH_INFO' in req.env:
            parts = req.env['PATH_INFO'].strip('/').split('/')
            repo_parts = req.env.get('REPO_NAME', '').split('/')
            if parts[:len(repo_parts)] == repo_parts:
                parts = parts[len(repo_parts):]
            query = '/'.join(parts)
        else:
            query = req.env['QUERY_STRING'].split('&', 1)[0]
            query = query.split(';', 1)[0]

        # process this if it's a protocol request
        # protocol bits don't need to create any URLs
        # and the clients always use the old URL structure

        cmd = req.form.get('cmd', [''])[0]
        if protocol.iscmd(cmd):
            try:
                if query:
                    raise ErrorResponse(HTTP_NOT_FOUND)
                if cmd in perms:
                    self.check_perm(rctx, req, perms[cmd])
                return protocol.call(self.repo, req, cmd)
            except ErrorResponse as inst:
                # A client that sends unbundle without 100-continue will
                # break if we respond early.
                if (cmd == 'unbundle' and
                    (req.env.get('HTTP_EXPECT',
                                 '').lower() != '100-continue') or
                    req.env.get('X-HgHttp2', '')):
                    req.drain()
                else:
                    req.headers.append(('Connection', 'Close'))
                req.respond(inst, protocol.HGTYPE,
                            body='0\n%s\n' % inst.message)
                return ''

        # translate user-visible url structure to internal structure

        args = query.split('/', 2)
        if 'cmd' not in req.form and args and args[0]:

            cmd = args.pop(0)
            style = cmd.rfind('-')
            if style != -1:
                req.form['style'] = [cmd[:style]]
                cmd = cmd[style + 1:]

            # avoid accepting e.g. style parameter as command
            if util.safehasattr(webcommands, cmd):
                req.form['cmd'] = [cmd]

            if cmd == 'static':
                req.form['file'] = ['/'.join(args)]
            else:
                if args and args[0]:
                    node = args.pop(0).replace('%2F', '/')
                    req.form['node'] = [node]
                if args:
                    req.form['file'] = args

            ua = req.env.get('HTTP_USER_AGENT', '')
            if cmd == 'rev' and 'mercurial' in ua:
                req.form['style'] = ['raw']

            if cmd == 'archive':
                fn = req.form['node'][0]
                for type_, spec in rctx.archivespecs.iteritems():
                    ext = spec[2]
                    if fn.endswith(ext):
                        req.form['node'] = [fn[:-len(ext)]]
                        req.form['type'] = [type_]

        # process the web interface request

        try:
            tmpl = self.templater(req)
            ctype = tmpl('mimetype', encoding=encoding.encoding)
            ctype = templater.stringify(ctype)

            # check read permissions non-static content
            if cmd != 'static':
                self.check_perm(rctx, req, None)

            if cmd == '':
                req.form['cmd'] = [tmpl.cache['default']]
                cmd = req.form['cmd'][0]

            if rctx.configbool('web', 'cache', True):
                caching(self, req) # sets ETag header or raises NOT_MODIFIED
            if cmd not in webcommands.__all__:
                msg = 'no such method: %s' % cmd
                raise ErrorResponse(HTTP_BAD_REQUEST, msg)
            elif cmd == 'file' and 'raw' in req.form.get('style', []):
                self.ctype = ctype
                content = webcommands.rawfile(rctx, req, tmpl)
            else:
                content = getattr(webcommands, cmd)(rctx, req, tmpl)
                req.respond(HTTP_OK, ctype)

            return content

        except (error.LookupError, error.RepoLookupError) as err:
            req.respond(HTTP_NOT_FOUND, ctype)
            msg = str(err)
            if (util.safehasattr(err, 'name') and
                not isinstance(err,  error.ManifestLookupError)):
                msg = 'revision not found: %s' % err.name
            return tmpl('error', error=msg)
        except (error.RepoError, error.RevlogError) as inst:
            req.respond(HTTP_SERVER_ERROR, ctype)
            return tmpl('error', error=str(inst))
        except ErrorResponse as inst:
            req.respond(inst, ctype)
            if inst.code == HTTP_NOT_MODIFIED:
                # Not allowed to return a body on a 304
                return ['']
            return tmpl('error', error=inst.message)

    def templater(self, req):

        # determine scheme, port and server name
        # this is needed to create absolute urls

        proto = req.env.get('wsgi.url_scheme')
        if proto == 'https':
            proto = 'https'
            default_port = "443"
        else:
            proto = 'http'
            default_port = "80"

        port = req.env["SERVER_PORT"]
        port = port != default_port and (":" + port) or ""
        urlbase = '%s://%s%s' % (proto, req.env['SERVER_NAME'], port)
        logourl = self.config("web", "logourl", "http://mercurial.selenic.com/")
        logoimg = self.config("web", "logoimg", "hglogo.png")
        staticurl = self.config("web", "staticurl") or req.url + 'static/'
        if not staticurl.endswith('/'):
            staticurl += '/'

        # some functions for the templater

        def motd(**map):
            yield self.config("web", "motd", "")

        # figure out which style to use

        vars = {}
        styles = (
            req.form.get('style', [None])[0],
            self.config('web', 'style'),
            'paper',
        )
        style, mapfile = templater.stylemap(styles, self.templatepath)
        if style == styles[0]:
            vars['style'] = style

        start = req.url[-1] == '?' and '&' or '?'
        sessionvars = webutil.sessionvars(vars, start)

        if not self.reponame:
            self.reponame = (self.config("web", "name")
                             or req.env.get('REPO_NAME')
                             or req.url.strip('/') or self.repo.root)

        def websubfilter(text):
            return websub(text, self.websubtable)

        # create the templater

        tmpl = templater.templater(mapfile,
                                   filters={"websub": websubfilter},
                                   defaults={"url": req.url,
                                             "logourl": logourl,
                                             "logoimg": logoimg,
                                             "staticurl": staticurl,
                                             "urlbase": urlbase,
                                             "repo": self.reponame,
                                             "encoding": encoding.encoding,
                                             "motd": motd,
                                             "sessionvars": sessionvars,
                                             "pathdef": makebreadcrumb(req.url),
                                             "style": style,
                                            })
        return tmpl

    def check_perm(self, rctx, req, op):
        for permhook in permhooks:
            permhook(rctx, req, op)
