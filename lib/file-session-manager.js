
var path = require('path'),
  fs = require('fs');

var FileSessionManager = function(sessionDir){
  // Check that the session dir exists

  this.sessionDir = sessionDir || path.join(__dirname, '../sessions/');
  if (! this.sessionDir.match(/\/$/)){
    this.sessionDir += '/';
  }

  if (!fs.existsSync(this.sessionDir)){
    fs.mkdirSync(this.sessionDir);
  }
}

module.exports = FileSessionManager;

(function(){
  this.serialize = function(user, done){
    fs.writeFile(this.sessionDir + user.id, 
      JSON.stringify(user), function(err){
        done(err, user.id);
      });
  }

  this.deserialize = function(id, done){
    fs.readFile(this.sessionDir + id, function(err, data){
      if(err){
        return done(err);
      }
      
      done(err, JSON.parse(data));
    });
  }
}).call(FileSessionManager.prototype);
