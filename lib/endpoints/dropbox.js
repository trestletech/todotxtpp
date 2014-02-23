
var DropboxOAuth2Strategy = require('passport-dropbox-oauth2').Strategy,
  path = require('path'),
  fs = require('fs'),
  _ = require('underscore'),
  passport = require('passport'),
  DropboxJS = require('dropbox');

var Dropbox = function(){
  // Read in the dropbox app settings.
  if (!fs.existsSync(path.join(__dirname, '../../dropbox.json'))){
    logger.error("Can't find the 'dropbox.json' file.");
    process.exit(1);
  }

  this.$dropboxSettings = JSON.parse(fs.readFileSync(
    path.join(__dirname, '../../dropbox.json'), { encoding : 'utf-8' }));

  if (!_.has(this.$dropboxSettings, 'key') || ! _.has(this.$dropboxSettings, 'secret')){
    logger.error("'dropbox.json' must provide a key and a secret.");
    process.exit(1);
  }
};
module.exports = Dropbox;

(function(){
  this.addMiddleware = function(app){
    passport.use(new DropboxOAuth2Strategy({
        clientID: this.$dropboxSettings.key,
        clientSecret: this.$dropboxSettings.secret,
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

    app.use('/list', function(req, res, next){
      if (!req.user || !req.user.accessToken){
        res.end(403);
      }
      if (!req.session || ! req.session.path){
        res.end(400);
      }
      var client = new DropboxJS.Client({token: req.user.accessToken});
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
  }
}).call(Dropbox.prototype);






  