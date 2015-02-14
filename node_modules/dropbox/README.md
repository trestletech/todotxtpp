# Client Library for the Dropbox API

This is a JavaScript client library for the Dropbox API,
[written in CoffeeScript](./guides/coffee_faq.md), suitable for use in both modern
browsers and in server-side code running under [node.js](http://nodejs.org/).


## Supported Platforms

This library is tested against the following JavaScript platforms.

* [node.js](http://nodejs.org/) 0.6, 0.8 and 0.10
* [Chrome](http://www.google.com/chrome) 31
* [Firefox](http://www.mozilla.org/firefox) 26
* [Internet Explorer](https://github.com/xdissent/ievms) 9 and 10
* [Chrome extensions](http://developer.chrome.com/extensions) in the Chrome
  browser mentioned above
* [Chrome packaged apps](http://developer.chrome.com/apps/) in the Chrome
  browser mentioned above
* [Cordova](http://cordova.apache.org/) 3.3.0

Keep in mind that the versions above are not hard requirements.


## Installation and Usage

The [getting started guide](./guides/getting_started.md) will help you get your
first dropbox.js application up and running.

The [code snippets guide](./guides/snippets.md) contains some JavaScript
fragments that may be useful in the latter stages of application development.
The [sample apps](./samples/) source code can be useful as a scaffold or as an
illustration of how all the pieces fit together.

The
[dropbox.js API reference](http://coffeedoc.info/github/dropbox/dropbox-js/master/class_index.html)
can be a good place to bookmark while building your application.

If you run into a problem, take a look at
[the dropbox.js GitHub issue list](https://github.com/dropbox/dropbox-js/issues).
Please [open a new issue](https://github.com/dropbox/dropbox-js/issues/new)
if your problem wasn't already reported.


## Versioning

This project mostly follows semantic versioning.

Until the library reaches version 1.0, changes to the public API will always
carry a minor version bump, such as going from 0.7.2 to 0.8.0. Patch releases
(e.g. 0.8.0 -> 0.8.1) may introduce new features that don't break the public
API.


## Development

The [development guide](./guides/development.md) will make your life easier if
you need to change the source code.

This library is written in CoffeeScript.
[These notes](./guides/coffee_faq.md) can help you understand if that matters
to you.


## Platform-Specific Issues

This lists the most serious problems that you might run into while using
`dropbox.js`. See
[the GitHub issue list](https://github.com/dropbox/dropbox-js/issues) for a
full list of outstanding problems.

### Internet Explorer 9

The library only works when used from `https://` pages, due to
[these issues](http://blogs.msdn.com/b/ieinternals/archive/2010/05/13/xdomainrequest-restrictions-limitations-and-workarounds.aspx).

Reading and writing binary files is unsupported.

At the moment, there are no plans for fixing these issues.


## Copyright and License

The library is Copyright (c) 2012 Dropbox Inc., and distributed under the MIT
License.
