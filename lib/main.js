
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

// Optional since express defaults to CWD/views

app.set('views', path.join(__dirname, '../views'));

// Set our default template engine to "jade"
// which prevents the need for extensions
// (although you can still mix and match)
app.set('view engine', 'jade');

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

    app.use(express.static(path.join(__dirname, '../public')));
    app.use(express.errorHandler());
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
        emails: _.map(profile.emails, function(mail){ return mail.value }),
        accessToken: accessToken
      });
    }
  ));

  app.get('/', function(req, res, next){
    vars = {};
    if (req.user && req.user.displayName){
      vars.username = req.user.displayName;
    }
    if (req.session && req.session.path){
      vars.path = req.session.path;
    }
    res.render('index', vars);
  });

  app.use('/list', function(req, res, next){
    if (!req.user || !req.user.accessToken){
      res.end(403);
    }
    if (!req.session || ! req.session.path){
      res.end(400);
    }
    client = new Dropbox.Client({token: req.user.accessToken});
    if (req.method === 'GET'){
      client.readFile(req.session.path, function(error, data) {
        if (error) {
          res.end(403);
          return;
        }
        res.json(data);
      });
      return;
    } else if (req.method==='POST'){
      if (!req.body){
        res.end(403);
        return;
      }
      client.writeFile(req.session.path, req.body.text, function(error, stat) {
        if (error) {
          res.end(403);
          return;
        }
        if (!stat._json || !stat._json.revision){
          res.end('OK');
          return;
        }
        res.end(JSON.stringify({
          revision: stat._json.revision, 
          versionTag: stat.versionTag
        }));
      });
      return;
    }
    res.end(400);    
  });

  app.post('/settings/path', function(req, res){
    req.session.path = req.body.path;
    res.end('OK');
  });

  app.get('/logout', function(req, res, next){
    req.session.reset();
    res.redirect('/');
  });

  app.get('/login',
    passport.authenticate('dropbox-oauth2'));

  app.get('/auth/dropbox/callback', 
    passport.authenticate('dropbox-oauth2', { failureRedirect: '/login' }),
    function(req, res) {
      res.redirect('/');
    });

  app.listen(3000);

});
