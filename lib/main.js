
var log4js = require('log4js');
global.logger = log4js.getLogger('todotxt');

var Q = require('q'),
  path = require('path'),
  express = require('express'),
  passport = require('passport'),
  KeyGenerator = require('./key-generator'),
  DropboxEndpoint = require('./endpoints/dropbox');

var app = express();
app.set('views', path.join(__dirname, '../views'));
app.set('view engine', 'jade');

// Used for persisting users. Will support different persistence engines
var PersistService = require('./persist/mongo');

var mongoURL = process.env['TODO_MONGO'] || 
  process.env['MONGOLAB_URI'] || 
  'mongodb://localhost/todotxtpp';

var SessionStore = require("session-mongoose")(express);
var store = new SessionStore({
    url: mongoURL + "/session"
});

var endpoint = new DropboxEndpoint(PersistService.User);

global.PORT = process.env.TODO_PORT || process.env.PORT || 3000;
global.DOMAIN = process.env.TODO_DOMAIN || ('http://localhost:' + global.PORT);
// Trim any trailing slash(es)
while (global.DOMAIN.match(/\/$/)){
  global.DOMAIN = global.DOMAIN.substring(0,global.DOMAIN.length-1);
}

var server;
if (process.env.TODO_SSL_KEY && process.env.TODO_SSL_CERT){
  server = require('https').createServer({
      key: fs.readFileSync(process.env.TODO_SSL_KEY),
      cert: fs.readFileSync(process.env.TODO_SSL_CERT)
    }, app).listen(PORT);
} else{
  server = require('http').createServer(app).listen(PORT);
}

// Generate a client session key
KeyGenerator.key_p({
  name: 'clientSessions', 
  bytes: 64,
  env: 'TODO_SESSION_KEY'
})
.then(function(sessionsKey){

  if (process.env.TODO_FORCE_DOMAIN){
    app.use(function(req, res, next){
      var protocol = req.headers['x-forwarded-proto'] || req.protocol;
      if (protocol !== global.DOMAIN.substring(0, global.DOMAIN.indexOf(':'))){
        logger.info("Redirecting due to " + protocol + " != " + global.DOMAIN.substring(0, global.DOMAIN.indexOf(':')));
        return res.redirect(global.DOMAIN + req.url);
      }
      if(global.DOMAIN.substring(global.DOMAIN.indexOf('://')+3) !== req.headers.host){
        logger.info("Redirecting due to : " + global.DOMAIN.substring(global.DOMAIN.indexOf('://')+3));
        return res.redirect(global.DOMAIN + req.url);
      }

      next();        
    });
  }

  app.use(express.favicon(path.join(__dirname, '../public/images/favicon.ico'))); 

  app.use(express.static(__dirname + '/../public'));
  app.use(express.bodyParser());
  app.use(express.cookieParser());
  app.use(express.bodyParser());
  app.use(express.session({ 
    cookie  : { maxAge  : new Date(Date.now() + (1000 * 60 * 60 * 24)) },
    secret: sessionsKey.toString('base64'),
    store: store
  }));
  app.use(passport.initialize());
  app.use(passport.session());
  app.use(express.static(path.join(__dirname, '../public')));
  app.use(express.errorHandler());

  endpoint.addMiddleware(app);

  // Middleware is all configured now.
  app.use(app.router);

  passport.serializeUser(function(user, done) {
    done(null, user._id);
  });

  passport.deserializeUser(function(id, done) {
    PersistService.User.findById(id, function(err, user){
     done(err, user)
    })
  });

  app.get('/', function(req, res, next){
    vars = {};
    if (req.user && req.user.displayName){
      vars.username = req.user.displayName;
    }
    if (req.user && req.user.path){
      vars.path = req.user.path;
    }
    vars.TODO_DOMAIN = global.DOMAIN;    
    res.render('index', vars);
  });

  app.get('/home', function(req, res, next){
    vars = {};
    if (req.user && req.user.displayName){
      vars.username = req.user.displayName;
    }
    if (req.user && req.user.path){
      vars.path = req.user.path;
    }
    res.render('home', vars);
  });

  app.use('/settings/path', function(req, res){
    req.user.path = req.body.path || req.query.path;
    req.user.save(function(err){
      if (!err){
        res.end('OK');
      } else{
        res.end(500);
      }
    });    
  });

  app.get('/logout', function(req, res, next){
    req.logout();
    res.redirect('/');
  });
});
