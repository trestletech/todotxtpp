fs = require 'fs'
path = require 'path'

run = require './run'

# Node 0.6 compatibility hack.
unless fs.existsSync
  fs.existsSync = (filePath) -> path.existsSync filePath

download = ([url, file], callback) ->
  if fs.existsSync file
    callback() if callback?
    return

  run "curl -o #{file} #{url}", callback

module.exports = download
