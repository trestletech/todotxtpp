glob = require 'glob'
open = require 'open'

run = require './run'

nodetest = (callback) ->
  reporter = if process.env['LIST'] then 'spec' else 'dot'

  test_cases = glob.sync 'test/js/**/*_test.js'
  test_cases.sort()  # Consistent test case order.
  run 'node node_modules/mocha/bin/mocha --colors --slow 200 ' +
      "--timeout 20000 --reporter #{reporter} --globals Dropbox " +
      '--require test/js/helpers/setup.js ' + test_cases.join(' ')

fasttest = (callback) ->
  reporter = if process.env['LIST'] then 'spec' else 'min'

  test_cases = glob.sync 'test/js/fast/**/*_test.js'
  test_cases.sort()  # Consistent test case order.
  run 'node node_modules/mocha/bin/mocha --colors --slow 200 --timeout 1000 ' +
      "--require test/js/helpers/fast_setup.js --reporter #{reporter} " +
      test_cases.join(' '), noExit: true, (code) ->
        callback(code) if callback

webtest = (callback) ->
  WebFileServer = require '../test/js/helpers/web_file_server.js'
  webFileServer = new WebFileServer()
  url = webFileServer.testUrl()
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

module.exports.fast = fasttest
module.exports.node = nodetest
module.exports.web = webtest
