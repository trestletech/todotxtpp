## Built-in OAuth Drivers

`dropbox.js` ships with the OAuth drivers below.

### Dropbox.AuthDriver.Redirect

The recommended built-in driver for browser applications completes the OAuth
token authorization step by redirecting the browser to the Dropbox page that
performs the authorization and having that page redirect back to the
application page.

Driver autodetection will automatically set up the Redirect driver in Web
applications, so calling `client.authDriver` is not necessary.

This driver's constructor takes the following options.

* `rememberUser` can be set to false to stop the driver from storing the user's
OAuth token in `localStorage`, so the user doesn't have to authorize the
application on every request

Although it seems that `rememberUser` should always be true, it brings a couple
of drawbacks. The user's token will still be valid after signing out of
the Dropbox web site, so your application will still recognize the user and
access their Dropbox. This behavior is unintuitive to users. A reasonable
compromise for apps that use the default `rememberUser` setting is to provide a
`Sign out` button that calls the `signOut` method on the app's `Dropbox.Client`
instance.

The [checkbox.js](../samples/checkbox.js) sample application implements signing
out as described above.


### Dropbox.AuthDriver.Popup

This driver may be useful for browser applications that can't handle the
redirections peformed by `Dropbox.AuthDriver.Redirect`. This driver avoids
changing the location of the application's browser window by popping up a
separate window, and loading the Dropbox authorization page in that window.

Most browsers will only display the popup window if `client.authorize()` is
called in response to a user action, such as click on a "Sign into Dropbox"
button. Browsers have different heuristics for deciding whether the condition
is met, so the safest bet is to make the `client.authorize()` call in a `click`
event listener.

To use the popup driver, create a page on your site that contains the
[receiver code](../test/html/oauth_receiver.html),
change the code to reflect the location of `dropbox.js` on your site, and point
the `Dropbox.AuthDriver.Popup` constructor to it.

```javascript
client.authDriver(new Dropbox.AuthDriver.Popup({
    receiverUrl: "https://url.to/oauth_receiver.html"}));
```

If your application needs to work in Internet Explorer, the receiver code must
be served from the same origin (protocol, host, port) as your application.

The popup driver implements the `rememberUser` option with the same semantics
and caveats as the Redirect driver.


### Dropbox.AuthDriver.ChromeExtension

Google Chrome [extensions](http://developer.chrome.com/extensions/) are
supported by a driver that performs the OAuth 2 flow in a dedicated tab.

To use this driver, first add the following files to your extension.

* the [receiver script](../test/src/helpers/chrome_oauth_receiver.coffee); the
file is both valid JavaScript and valid CoffeeScript
* the [receiver page](../test/html/chrome_oauth_receiver.html); change the page
to reflect the paths to `dropbox.js` and to the receiver script file

The receiver page (the `chrome_oauth_receiver.html` file) must be added to the
[web_accessible_resources section](http://developer.chrome.com/extensions/manifest/web_accessible_resources.html)
of your extension's `manifest.json`.

Point the driver constructor to the receiver page:

```javascript
client.authDriver(new Dropbox.AuthDriver.ChromeExtension({
  receiverPath: "path/to/chrome_oauth_receiver.html"}));
```

This driver caches the user's credentials so that users don't have to authorize
extensions on every browser launch. Extensions' UI should include a method
for the user to sign out of Dropbox, which can be implemented by calling the
`signOut` instance method of `Dropbox.Client`.


### Dropbox.AuthDriver.ChromeApp

Google Chrome
[packaged applications](http://developer.chrome.com/apps/) are supported by a
driver that uses the
[identity API](http://developer.chrome.com/apps/identity.html)
to complete the OAuth 2 flow.

To use this driver, add the `identity` permission to your application's
`manifest.json` file.

Driver autodetection will automatically set up the ChromeApp driver in Chrome
packaged applications, so calling `client.authDriver` is not necessary.

This driver caches the user's credentials so that users don't have to authorize
applications on every browser launch. Applications' UI should include a method
for the user to sign out of Dropbox, which can be implemented by calling the
`signOut` instance method of `Dropbox.Client`.

This drive can be used with Chrome extensions. However, to avoid
[these user experience issues](http://crbug.com/281676), the
Dropbox.AuthDriver.ChromeExtension driver should be used instead.


### Dropbox.AuthDriver.Cordova

This driver uses Cordova's
[InAppBrowser](http://cordova.apache.org/docs/en/3.0.0/cordova_inappbrowser_inappbrowser.md.html)
to open a popup-like activity that completes the OAuth authorization.

```javascript
client.authDriver(new Dropbox.AuthDriver.Cordova());
```

This driver implements the `rememberUser` option with the same semantics and
caveats as the redirecting driver.


In theory, the Redirect driver should work for Cordova applications. However,
[this bug](https://code.google.com/p/android/issues/detail?id=17327) prevents
it from working on Android, so a cross-platform application should use the
Cordova-specific driver.


### Dropbox.AuthDriver.NodeServer

This driver is designed for use in the automated test suites of node.js
applications. It completes the OAuth token authorization step by opening the
Dropbox authorization page in a new browser window, and "catches" the OAuth
redirection by setting up a small server using the `https` built-in node.js
library.

The driver's constructor takes the following options.

* `port` is the HTTP port number; the default is 8192, and works well with the
Chrome extension described below
* `favicon` is a path to a file that will be served in response to requests to
`/favicon.ico`; setting this to a proper image will avoid some warnings in the
browsers' consoles

To fully automate your test suite, you need to load up the Chrome extension
bundled in the `dropbox.js` source tree. The extension automatically clicks on
the "Authorize" button in the Dropbox token authorization page, and closes the
page after the token authorization process completes. Follow the steps in the
[development guide](./development.md) to build and install the extension.

