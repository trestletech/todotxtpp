
var Dropbox = require('dropbox'),
  Q = require('q'),
  fs = require('fs'),
  path = require('path'),
  log4js = require('log4js'),
  _ = require('underscore'),
  express = require('express'),
  passport = require('passport'),
  DropboxOAuth2Strategy = require('passport-dropbox-oauth2').Strategy,
  sessionManager = require('./file-session-manager');

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

var client = new Dropbox.Client({
  key: dropboxSettings.key,
  secret: dropboxSettings.secret
});

//client.authDriver(new Dropbox.AuthDriver.NodeServer(8191));

var app = express();

app.configure(function() {
  app.use(express.static(__dirname + '/../public'));
  app.use(express.bodyParser());
  app.use(express.cookieParser());
  app.use(express.bodyParser());
  app.use(express.session({ secret: 'keyboard cat' }));  
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
    console.log(profile);
    return done(null, {
      id: profile.id,
      email: profile.email,
      displayName: profile.displayName,
      emails: profile.emails
    });
  }
));

app.get('/', function(req, res, next){
  res.end("<html>Authed as : " + JSON.stringify(req.user) + '<br /><a href = "/login">Login</a></html>');  
});

app.get('/login', function(req, res, next){
  res.end('<a href = "/auth/dropbox">Login with Dropbox</a>');
});

app.get('/auth/dropbox',
  passport.authenticate('dropbox-oauth2'));

app.get('/auth/dropbox/callback', 
  passport.authenticate('dropbox-oauth2', { failureRedirect: '/login' }),
  function(req, res) {
    req.session.user = req.user;
    res.redirect('/');
  });

app.listen(3000);

/*client.authenticate(function(error, client) {
  if (error) {
    logger.error(error);
    return false;
  }

  logger.info("We made it");
});*/