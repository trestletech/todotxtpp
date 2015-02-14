# Breaking Changes in dropbox.js 0.10

This document is intended to help developers using `dropbox.js` versions prior
to 0.10 quickly update their code to migrate to the 0.10 release.

`dropbox.js` 0.10 uses [OAuth 2.0](http://tools.ietf.org/html/rfc6749) instead
of OAuth 1.0a, renames many classes, and changes some default options on
constructors.


## OAuth 2.0

[OAuth 2.0](http://tools.ietf.org/html/rfc6749) will make Web applications more
responsive, because the authorization process uses fewer requests to the
Dropbox API servers, and because it adds less overhead to normal API requests.

In return, the authorization process is more complex than its OAuth 1.0a
equivalent, and the API that OAuth drivers have to implement has changed.
[The guide to OAuth drivers](guides/auth_drivers.md) describes the new
interface.


## Class Renames

Second-level namespaces were introduced so that `dropbox.js` can keep growing.
The actual class APIs are still backwards-compatible.

The code snippet below reinstates the old names, and allows old code to use
`dropbox.js` 0.10 without modification. It also suggests a sequence of
find-and-replace operations that can be performed on old code to switch to the
new names.

```javascript
Dropbox.CopyReference = Dropbox.File.CopyReference;
Dropbox.Drivers = Dropbox.AuthDriver;  // namespace change
Dropbox.EventSource = Dropbox.Util.EventSource;
Dropbox.Oauth = Dropbox.Util.Oauth;
Dropbox.PublicUrl = Dropbox.File.ShareUrl;  // class rename
Dropbox.PullChange = Dropbox.Http.PulledChange;  // class rename
Dropbox.PulledChanges = Dropbox.Http.PulledChanges;
Dropbox.RangeInfo = Dropbox.Http.RangeInfo;
Dropbox.Stat = Dropbox.File.Stat;
Dropbox.UploadCursor = Dropbox.Http.UploadCursor;
Dropbox.UserInfo = Dropbox.AccountInfo;  // class rename
Dropbox.Xhr = Dropbox.Util.Xhr;
```


## Default Changes

`rememberUser` now defaults to `true` in the built-in OAuth drivers. Most
developers end up using the drivers in this mode. Applications that do not set
`rememberUser` should either implement a method for the user to sign out that
uses
[Dropbox.Client#signOut](http://coffeedoc.info/github/dropbox/dropbox-js/master/classes/Dropbox/Client.html#signOut-instance),
or explicitly pass `rememberUser: false` to the constructor of the OAuth driver
that they use.

The
[Dropbox.Client constructor](http://coffeedoc.info/github/dropbox/dropbox-js/master/classes/Dropbox/Client.html#constructor-instance)
does not need the `sandbox` option for App Folder applications. The option is
now completely ignored.

Calling
[Dropbox.Client#authDriver](http://coffeedoc.info/github/dropbox/dropbox-js/master/classes/Dropbox/Client.html#authDriver-instance)
to set up an OAuth driver is now optional in browser applications, Chrome
applications/extensions, and Cordova applications. If an OAuth driver is not
set up, the recommended driver for each platform will be used. Server
environments still require an `authDriver` call.
