glob = require 'glob'
open = require 'open'

run = require './run'

webconsole = (callback) ->
  WebFileServer = require '../test/js/helpers/web_file_server.js'
  webFileServer = new WebFileServer()
  url = webFileServer.consoleUrl()
  if 'BROWSER' of process.env
    if process.env['BROWSER'] is 'false'
      console.log "Please open the URL below in your browser:\n    #{url}"
      callback() if callback?
    else
      open url, process.env['BROWSER'], ->
        callback() if callback?
  else
    open url, ->
      callback() if callback?
  callback() if callback?

module.exports.web = webconsole

