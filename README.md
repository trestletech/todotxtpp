
Todo.txt++
==========

A NodeJS web application that supports interfacing with the [Todo.txt](http://todotxt.com/) protocol with Dropbox integration.

## Setup & Configuration

### Dropbox Application

You'll need to register a Dropbox application which can be done [here](https://www.dropbox.com/developers/apps). You app needs to be a "Dropbox API app" with access to all files (not only the ones it creates) but only of the "Text" type.

Once you register the app, place the key and secret in a file named `dropbox.json` (you can use the existing file [dropbox.json.example](/blob/master/dropbox.json.example) to guide you) in this directory. Todo.txt++ will pick up these settings the next time it starts and interacting with Dropbox as the application you registered.

### Session Key

Rather than storing information in a centralized database, Todo.txt++ stores user information in encrypted cookies on the user's browsers. This simplifies the setup/maintenance process as you don't have to worry about maintaining a database on your server. 

The cookies are encrypted using a binary file in this directory named `clientSessions.key` which will be generated for you (using a secure, cryptographic generator) the first time you run the application if it doesn't exist. Feel free to modify this file to specify your own key, but be aware that changing the key will invalidate all existing cookies stored on your visitor's browsers. So they'll all need to go through the login/Dropbox approval screen again the next time they visit.
