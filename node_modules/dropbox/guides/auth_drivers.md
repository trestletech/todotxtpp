# Authentication Drivers

This document explains the structure and functionality of a `dropbox.js` OAuth
driver, and is intended to help the development of custom OAuth drivers.
[builtin_drivers.md](The built-in OAuth drivers) are a good starting point for
new implementations.


## OAuth 2 Overview

The bulk of OAuth 2 is a process by which Dropbox users authorize your
application to access their Dropbox. At the end of the process, your applcation
obtains an access token, which is an opaque string of 64-128 URL-safe
characters. The access token identifies your application and the user who
authorized it.

The OAuth 2 authorization process has two slightly different variants,
depending on whether the application developers control and trust the
environment that runs the code using `dropbox.js`

* If `dropbox.js` runs in an application server (for example, in a node.js
  applcation), the environment is considered trusted. The documentation refers
  to this as the _server-side application_ case.

* If `dropbox.js` runs in a client-side environment, such as in a Web browser
  or mobile application, the environment is untrusted. The documentation refers
  to this as the _browser-side application_ case. The term "client-side" would
  be more accurate, but it is not used to avoid creating a confusion with the
  concept of client in OAuth-related documentation.

### Browser-Side Applications



### Server-Side Applications




## The OAuth Driver Interface

The core logic of the OAuth 2 authorization process is implemented by the

An OAuth driver is a JavaScript object that implements the methods documented
in the
[Dropbox.AuthDriver class](http://coffeedoc.info/github/dropbox/dropbox-js/master/classes/Dropbox/AuthDriver.html).
This class exists solely for the purpose of documenting these methods.

A simple driver can get away with implementing `url` and `doAuthorize`. The
following example shows an awfully unusable node.js driver that asks the user
to visit the authorization URL in a browser.

TODO(pwnall): rewrite this example, because OAuth2 broke the simple model below

```javascript
var util = require("util");
var simpleDriver = {
  url: function() { return ""; },
  doAuthorize: function(authUrl, stateParm, client, callback) {
    util.print("Visit the following in a browser, then press Enter\n" +
                authUrl + "\n");
    var onEnterKey = function() {
      process.stdin.removeListener("data", onEnterKey);
      callback(token);
    }
    process.stdin.addListener("data", onEnterKey);
    process.stdin.resume();
  }
};
```

Complex drivers can take control of the OAuth process by implementing
`onAuthStepChange`. Implementations of this method should read the `authStep`
field of the `Dropbox.Client` instance they are given to make decisions.
Implementations should call the `credentials` and `setCredentials` methods on
the client to control the OAuth process.

See the
[Dropbox.AuthDriver.Chrome source](../src/auth_driver/chrome.coffee)
for a sample implementation of `onAuthStepChange`.


### The OAuth 2.0 Process Steps

The `authenticate` method in `Dropbox.Client` implements the OAuth process as a
finite state machine (FSM). The current state is available in the `authStep`
field.

The authentication FSM has the following states.

* `Dropbox.Client.RESET` is the initial state, where the client has no OAuth
tokens; after `onAuthStepChange` is triggered, the client will attempt to
obtain an OAuth request token
* `Dropbox.Client.REQUEST` indicates that the client has obtained an OAuth
request token; after `onAuthStepChange` is triggered, the client will call
`doAuthorize` on the OAuth driver, to get the OAuth request token authorized by
the user
* `Dropbox.Client.AUTHORIZED` is reached after the `doAuthorize` calls its
callback, indicating that the user has authorized the OAuth request token;
after `onAuthStepChange` is triggered, the client will attempt to exchange the
request token for an OAuth access token
* `Dropbox.Client.DONE` indicates that the OAuth process has completed, and the
client has an OAuth access token that can be used in API calls; after
`onAuthStepChange` is triggered, `authorize` will call its callback function,
and report success
* `Dropbox.Client.SIGNED_OUT` is reached when the client's `signOut` method is
called, after the API call succeeds; after `onAuthStepChange` is triggered,
`signOut` will call its callback function, and report success
* `Dropbox.Client.ERROR` is reached if any of the Dropbox API calls used by
`authorize` or `signOut` results in an error; after `onAuthStepChange` is
triggered, `authorize` or `signOut` will call its callback function and report
the error


