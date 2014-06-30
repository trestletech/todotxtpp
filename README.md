
Todo.txt++
==========

A NodeJS web application that supports interfacing with the [Todo.txt](http://todotxt.com/) protocol with Dropbox integration. Hosted online at [http://todotxtpp.com](http://todotxtpp.com).

![Todo.txt++ Screenshot](http://trestletech.github.io/todotxtpp/images/todo-screenshot.png)

### Features
 - Dropbox synchronization
 - Text editor with Todo.txt syntax highlighting
 - Select any text file in your Dropbox account to use
 - Mobile-friendly layout based on Twitter Bootstrap.
 - Searching/filtering

### In the Works

 - A GUI for managing tasks
 - A syntax and automated management for recurring tasks (we'll add tasks for you where appropriate)
  - [You tell us...](https://github.com/trestletech/todotxtpp/issues)

## Running the Code

We host a version that you can use for free at [http://todotxtpp.com](http://todotxtpp.com). But if you want to modify the software or run your own copy...

Make sure you've followed the instructions below about registering a Dropbox application. You will also need a MongoDB instance -- if it's not running locally on the default ports, you'll need to use the `TODO_MONGO` environment variable to point to it. Then clone this repository then from the base directory execute:

```bash
npm install
node lib/main.js
```

You should then be able to access the site at [http://localhost:3000/](http://localhost:3000).

The code should be [Heroku](http://heroku.com)-friendly, you'll just need to `config:set` the environment variables below.

## Setup & Configuration

### Environment Variables

For now, the application is largely controlled through environment variables rather than a configuration file. The following variables are available:

 - `TODO_DOMAIN`* - The full domain (with protocol and port) of the server you're running on, as accessed by your clients. This is needed in order for Dropbox to refer the client back to your server when logging in.
 - `TODO_DROPBOX_KEY`* - The key of your Dropbox application to use for Dropbox OAuth (see the "Dropbox Application" section below).
 - `TODO_DROPBOX_SECRET`* - The secret of your Dropbox application to use for Dropbox OAuth (see the "Dropbox Application" section below).
 - `TODO_MONGO`* - The MongoDB URI. Defaults to `mongodb://localhost/todotxtpp`.
 - `TODO_PORT` or, if that's not found, `PORT`- The port on which the server will be created. By default, `3000`.
 - `TODO_SESSION_KEY` - If you don't want a private sessions key to be generated for you, you can specify your own in this variable. Note that this configuration will override any key found in `clientSessions.key`.
 - `TODO_SSL_KEY` - The full path to the SSL key to use in creating an HTTPS server. You must also specify a `TODO_SSL_CERT` variable in order for this setting to have any effect.
 - `TODO_SSL_CERT` - The full path to the SSL certificate to use in creating an HTTPS server. You must also specify a `TODO_SSL_KEY` variable in order for this setting to have any effect.
 - `TODO_FORCE_DOMAIN` - Will force visitors to use the exact domain you provided when visiting the site (including HTTP/S and the presence/lack of a `www` prefix). Default is false. Set to `1` to enable. Provides a convenient way to ensure that your users are using the proper protocol and prefix.

*Settings you must provide.

### Persistence

For the sake of simplicity, everything (sessions, users, settings, whatever) are all stored in MongoDB. Sessions are set to expire and be reaped from the database one day from their last use.

### Dropbox Application

You'll need to register a Dropbox application which can be done [here](https://www.dropbox.com/developers/apps). You app needs to be a "Dropbox API app" with access to all files (not only the ones it creates) but only of the "Text" type.

Once you register the app, place the key and secret in a file named `dropbox.json` (you can use the existing file [dropbox.json.example](/dropbox.json.example) to guide you) in this directory. Alternatively, you can set the environment variables `TODO_DROPBOX_KEY` and `TODO_DROPBOX_SECRET`. Todo.txt++ will pick up these settings the next time it starts and interact with Dropbox as the application you registered.

### Session Key

Session cookies are secured using a binary file in this directory named `clientSessions.key` which will be generated for you (using a secure, cryptographic generator) the first time you run the application if it doesn't exist. Feel free to modify this file to specify your own key, but be aware that changing the key will invalidate all existing sessions.

### External Assets

Most libraries we can load unaltered from CDNs. The [Ace Editor](http://ace.c9.io), however, is custom as we added a Todo.txt syntax highlighter that doesn't come standard. (The highlighting regex rules were initially taken from [this project](https://github.com/dertuxmalwieder/SublimeTodoTxt).) To build this yourself, you'll need to clone [the forked repo](https://github.com/trestletech/ace) which has this custom Syntax highlighter.
