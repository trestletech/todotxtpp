
var path = require('path'),
  fs = require('fs');

exports.serialize = function(user, done){
  fs.writeFile(path.join(__dirname, '../sessions/' + user.id), 
    JSON.stringify(user), function(err){
      done(err, user.id);
    });
}

exports.deserialize = function(id, done){
  fs.readFile(path.join(__dirname, '../sessions/' + id), function(err, data){
    if(err){
      return done(err);
    }
    
    done(err, JSON.parse(data));
  });
}