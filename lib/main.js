
var Dropbox = require('dropbox'),
  Q = require('q'),
  fs = require('fs'),
  path = require('path'),
  log4js = require('log4js'),
  _ = require('underscore'),
  express = require('express'),
  passport = require('passport'),
  DropboxOAuth2Strategy = require('passport-dropbox-oauth2').Strategy,
  FileSessionManager = require('./file-session-manager'),
  url = require('url'),
  clientSessions = require("client-sessions"),
  KeyGenerator = require('./key-generator');

var sessionManager = new FileSessionManager();

global.logger = log4js.getLogger();

// Read in the dropbox app settings.
if (!fs.existsSync(path.join(__dirname, '../dropbox.json'))){
  logger.error("Can't find the 'dropbox.json' file.");
  process.exit(1);
}

var dropboxSettings = JSON.parse(fs.readFileSync(
  path.join(__dirname, '../dropbox.json'), { encoding : 'utf-8' }));

if (!_.has(dropboxSettings, 'key') || ! _.has(dropboxSettings, 'secret')){
  logger.error("'dropbox.json' must provide a key and a secret.");
  process.exit(1);
}


var app = express();

KeyGenerator.key_p({
  name: 'clientSessions', 
  bytes: 64
})
.then(function(sessionsKey){
  app.configure(function() {
    app.use(express.static(__dirname + '/../public'));
    app.use(express.bodyParser());
    app.use(express.cookieParser());
    app.use(express.bodyParser());
    app.use(clientSessions({
      cookieName: 'session', // cookie name dictates the key name added to the request object
      secret: sessionsKey, // should be a large unguessable string
      duration: 24 * 60 * 60 * 1000, // how long the session will stay valid in ms
      activeDuration: 1000 * 60 * 5 // if expiresIn < activeDuration, the session will be extended by activeDuration milliseconds
    }));
    app.use(passport.initialize());
    app.use(passport.session());
    app.use(app.router);
  });

  passport.serializeUser(function(user, done) {
    sessionManager.serialize(user, done);
  });

  passport.deserializeUser(function(id, done) {
    sessionManager.deserialize(id, done);
  });

  passport.use(new DropboxOAuth2Strategy({
      clientID: dropboxSettings.key,
      clientSecret: dropboxSettings.secret,
      callbackURL: "http://localhost:3000/auth/dropbox/callback"
    },
    function(accessToken, refreshToken, profile, done) {
      return done(null, {
        id: profile.id,
        email: profile.email,
        displayName: profile.displayName,
        emails: profile.emails,
        accessToken: accessToken
      });
    }
  ));

  app.get('/', function(req, res, next){
    res.end("<html>Authed as : " + JSON.stringify(req.user) + '<br /><a href = "/login">Login</a></html>');  
  });

  app.get('/info', function(req, res, next){
    client = new Dropbox.Client({token: req.user.accessToken});
    client.getAccountInfo(function(error, accountInfo) {
      if (error) {
        res.end(500);
        console.log(error);
        return;
      }

      res.end(accountInfo.name);
    });
  });

  app.get('/login', function(req, res, next){
    res.end('<a href = "/auth/dropbox">Login with Dropbox</a>');
  });

  app.get('/auth/dropbox',
    passport.authenticate('dropbox-oauth2'));

  app.get('/auth/dropbox/callback', 
    passport.authenticate('dropbox-oauth2', { failureRedirect: '/login' }),
    function(req, res) {
      res.redirect('/');
    });

  app.listen(3000);

});
