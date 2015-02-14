async = require 'async'
fs = require 'fs-extra'

clean = (callback) ->
  dirs = [
    'doc',
    'sitedoc/all.json',
    'sitedoc/html',
    'sitedoc/yaml',
    'test/cordova_app',
    'test/js',
    'tmp'
  ]
  cleanDir = (dirName, callback) ->
    fs.exists dirName, (exists) ->
      unless exists
        callback() if callback
        return
      fs.remove dirName, (error) ->
        callback() if callback
  async.forEachSeries dirs, cleanDir, ->
    callback() if callback

module.exports = clean
