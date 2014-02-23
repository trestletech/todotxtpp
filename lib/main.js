
var log4js = require('log4js');
global.logger = log4js.getLogger('todotxt');

var Q = require('q'),
  path = require('path'),
  express = require('express'),
  passport = require('passport'),
  FileSessionManager = require('./file-session-manager'),
  clientSessions = require("client-sessions"),
  KeyGenerator = require('./key-generator'),
  DropboxEndpoint = require('./endpoints/dropbox.js');

var sessionManager = new FileSessionManager();

var app = express();
app.set('views', path.join(__dirname, '../views'));
app.set('view engine', 'jade');

var endpoint = new DropboxEndpoint();

// Generate a client session key
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

  app.get('/home', function(req, res, next){
    vars = {};
    if (req.user && req.user.displayName){
      vars.username = req.user.displayName;
    }
    if (req.session && req.session.path){
      vars.path = req.session.path;
    }
    res.render('home', vars);
  });

  endpoint.addMiddleware(app);

  app.use('/settings/path', function(req, res){
    req.session.path = req.body.path || req.query.path;
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
