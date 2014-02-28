
var mongoose = require('mongoose');

mongoose.connect( process.env['TODO_MONGO'] || 
  process.env['MONGOLAB_URI'] || 
  'mongodb://localhost/todotxtpp');

// This class must have:
//  - findById(id, callback(err, user))
//  - save(callback(err))
//  - findOne({ key : 'val' }, callback( err, user ))
exports.User = mongoose.model('User', {
  dropboxID: Number,
  email: String,
  displayName: String,
  accessToken: String
})
