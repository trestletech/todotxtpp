# Code Snippets

This document contains code snippets that solve frequently asked questions.


## "Sign into Dropbox" Button

Some applications wish to start the Dropbox authorization flow when the user
clicks on a "Sign into Dropbox" button. If the user has already authorized the
application, the button should not be shown. The code below accomplishes this
task, assuming that the signin button is initially hidden.

```javascript
// Try to use cached credentials.
client.authenticate({interactive: false}, function(error, client) {
  if (error) {
    return handleError(error);
  }
  if (client.isAuthenticated()) {
    // Cached credentials are available, make Dropbox API calls.
    doSomethingCool();
  } else {
    // show and set up the "Sign into Dropbox" button
    var button = document.querySelector("#signin-button");
    button.setAttribute("class", "visible");
    button.addEventListener("click", function() {
      // The user will have to click an 'Authorize' button.
      client.authenticate(function(error, client) {
        if (error) {
          return handleError(error);
        }
        doSomethingCool();
      });
    });
  }
});
```


## Binary File Reads

By default, `readFile` assumes that the Dropbox file contents is a UTF-8
encoded string. This works for text files, but is unsuitable for images and
other binary files. When reading binary files, one of the following
[readFile options](http://coffeedoc.info/github/dropbox/dropbox-js/master/classes/Dropbox/Client.html#readFile-instance)
should be used: `arrayBuffer`, `blob` (only works in browsers),
`buffer` (node.js only).

```javascript
client.readFile("an_image.png", { arrayBuffer: true }, function(error, data) {
  if (error) {
    return handleError(error);
  }
  // data is an ArrayBuffer instance holding the image.
});
```


## Binary File Writes in node.js

When the `data` argument to `writeFile` is a JavaScript string, `writeFile`
uses the UTF-8 encoding to send the contents to the Dropbox. This works for
text files, but is unsuitable for images and other binary files. `Buffer` and
`ArrayBuffer` instances are transmitted without any string encoding, and are
suitable for binary files.

```javascript
fs.readFile("some_image.png", function(error, data) {
  // No encoding passed, readFile produces a Buffer instance
  if (error) {
    return handleNodeError(error);
  }
  client.writeFile("the_image.png", data, function(error, stat) {
    if (error) {
      return handleError(error);
    }
    // The image has been succesfully written.
  });
});
```


## Progress indicators

When working with large files, it is desirable to show progress indicators in
the UI. Thos can be accomplished by listening to the `progress` event of the
XMLHttpRequest used to download or upload a file.

The code snippet below can be used to track the progress of a file download.

```javascript
var xhrListener = function(dbXhr) {
  dbXhr.xhr.addEventListener("progress", function(event) {
    // event.loaded bytes received, event.total bytes must be received
    reportProgress(event.loaded, event.total);
  });
  return true;  // otherwise, the XMLHttpRequest is canceled
};
client.onXhr.addListener(xhrListener);
client.readFile("some_large_file.iso", function(error, data, stat) {
  stopReportingProgress();
});
client.onXhr.removeListener(xhrListener);
```

The code snippet below can be used to track the progress of a file upload.

```javascript
var xhrListener = function(dbXhr) {
  dbXhr.xhr.upload.onprogress("progress", function(event) {
    // event.loaded bytes received, event.total bytes must be received
    reportProgress(event.loaded, event.total);
  });
  return true;  // otherwise, the XMLHttpRequest is canceled
};
client.onXhr.addListener(xhrListener);
client.writeFile("some_large_file.iso", data, function(error, stat) {
  stopReportingProgress();
});
client.onXhr.removeListener(xhrListener);
```
