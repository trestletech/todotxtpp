
Todo.txt++
==========

A NodeJS web application that supports interfacing with the [Todo.txt](http://todotxt.com/) protocol with Dropbox integration.

## Setup & Configuration

### Environment Variables

For now, the application is largely controlled through environment variables rather than a configuration file. The following variables are available:

 - `TODO_PORT` or, if that's not found, `PORT`- The port on which the server will be created. By default, `3000`.
 - `TODO_SSL_KEY` - The full path to the SSL key to use in creating an HTTPS server. You must also specify a `TODOCERT` variable in order for this setting to have any effect.
 - `TODO_SSL_CERT` - The full path to the SSL certificate to use in creating an HTTPS server. You must also specify a `TODOKEY` variable in order for this setting to have any effect.
 - `TODO_DOMAIN` - The full domain (with protocol and port) of the server you're running on, as accessed by your clients. This is needed in order for Dropbox to refer the client back to your server when logging in.
 - `TODO_DROPBOX_KEY` - The key of your Dropbox application to use for Dropbox OAuth (see the "Dropbox Application" section below).
 - `TODO_DROPBOX_SECRET` - The secret of your Dropbox application to use for Dropbox OAuth (see the "Dropbox Application" section below).
 - `TODO_SESSION_KEY` - If you don't want a private sessions key to be generated for you, you can specify your own in this variable. Note that this configuration will override any key found in `clientSessions.key`.
 - `TODO_FORCE_DOMAIN` - Will force visitors to use the exact domain you provided when visiting the site (including HTTP/S and the presence/lack of a `www` prefix). Default is false. Set to `1` to enable. Provides a convenient way to ensure that your users are using the proper protocol and prefix.

### Dropbox Application

You'll need to register a Dropbox application which can be done [here](https://www.dropbox.com/developers/apps). You app needs to be a "Dropbox API app" with access to all files (not only the ones it creates) but only of the "Text" type.

Once you register the app, place the key and secret in a file named `dropbox.json` (you can use the existing file [dropbox.json.example](/dropbox.json.example) to guide you) in this directory. Alternatively, you can set the environment variables `TODO_DROPBOX_KEY` and `TODO_DROPBOX_SECRET`. Todo.txt++ will pick up these settings the next time it starts and interacting with Dropbox as the application you registered.

### Session Key

Rather than storing information in a centralized database, Todo.txt++ stores user information in encrypted cookies on the user's browsers. This simplifies the setup/maintenance process as you don't have to worry about maintaining a database on your server. 

The cookies are encrypted using a binary file in this directory named `clientSessions.key` which will be generated for you (using a secure, cryptographic generator) the first time you run the application if it doesn't exist. Feel free to modify this file to specify your own key, but be aware that changing the key will invalidate all existing cookies stored on your visitor's browsers. So they'll all need to go through the login/Dropbox approval screen again the next time they visit.

### External Assets

Most libraries we can load unaltered from CDNs. The [Ace Editor](http://ace.c9.io), however, is custom as we added a Todo.txt syntax highlighter that doesn't come standard. (The highlighting regex rules were initially taken from [this project](https://github.com/dertuxmalwieder/SublimeTodoTxt).) To build this yourself, you'll need to clone [the forked repo](https://github.com/trestletech/ace) which has this custom Syntax highlighter.