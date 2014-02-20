
var Q = require('q'),
crypto = require('crypto'),
fs = require('fs'),
path = require('path');

/**
 * @param format (optional) If falsy, will return the raw buffer, otherwise can 
 *   specify the output format of the key as in 'hex' or 'base64'.
 * @param bytes (optional) The number of bytes to use for the key.
 **/
exports.generate_p = generate_p;
function generate_p(format, bytes){
  var prom = Q.defer(); 

  if (!bytes){
    bytes = 16;
  }

  crypto.randomBytes(bytes, function(ex, buf) {
    var toReturn = buf;
    if (format){
      buf = buf.toString(format);
    }
    prom.resolve(buf);
  });

  return prom.promise;
}

exports.key_p = key_p;
function key_p(options){
  var prom = Q.defer();

  if (typeof options === 'string'){
    options = {name: options};
  }

  if (options.name){
    // Working with a named key. Need to check to see if file exists.
    var filename = path.join(__dirname, '../', options.name + '.key');

    // Try to read the file.
    return Q.nfcall(fs.readFile, filename)
    .then(function(buf){
      return formatKey(buf, options.format);
    }, function(err){
      // Error reading the file. Presume it doesn't exist.
      // No such key. Generate it and save it.
      if (!options.bytes){
        options.bytes = 16;
      }

      return generate_p(false, options.bytes)
      .then(function(key){
        // Save the key in a file
        return Q.nfcall(fs.writeFile, filename, key)
        .then(function(){
          return formatKey(key, options.format);
        });
      });
    });
  } else{
    return generate_p(options.format, options.bytes);
  }

  return prom.promise;
}

function formatKey(buf, format){
  if (format){
    return buf.toString(format);  
  }
  return buf;
}