if global? and require? and module? and (not cordova?)
  # node.js
  require('source-map-support').install()

  exports = global

  exports.Dropbox = require '../../../lib/dropbox'
  exports.chai = require 'chai'
  exports.sinon = require 'sinon'
  exports.sinonChai = require 'sinon-chai'

  tlsOptions = key: require('fs').readFileSync('test/ssl/cert.pem')
  tlsOptions.cert = tlsOptions.key
  exports.authDriver = new Dropbox.AuthDriver.NodeServer(
      tls: tlsOptions, port: 8912)

  TokenStash = require './token_stash.js'
  stash = new TokenStash()
  stash.get (credentials) ->
    exports.testKeys = credentials.sandbox
    exports.testFullDropboxKeys = credentials.full

  WebFileServer = require './web_file_server.js'
  webFileServer = new WebFileServer()
  exports.testXhrServer = webFileServer.testOrigin()

  testImagePath = './test/binary/dropbox.png'
  fs = require 'fs'
  buffer = fs.readFileSync testImagePath
  exports.testImageBytes = (buffer.readUInt8(i) for i in [0...buffer.length])
else
  if chrome?.runtime?.id
    # Chrome.app or extension.
    exports = window
    if chrome.tabs and chrome.tabs.create
      # Chrome extension.
      exports.authDriver = new Dropbox.AuthDriver.ChromeExtension(
          receiverPath: 'test/html/chrome_oauth_receiver.html',
          scope: 'helper-chrome')
    else
      # Chrome app.
      exports.authDriver = new Dropbox.AuthDriver.ChromeApp(
          scope: 'helper-chrome')

    # Hack-implement "rememberUser: false" in the Chrome driver.
    exports.authDriver.storeCredentials = (credentials, callback) -> callback()
    exports.authDriver.loadCredentials = (callback) -> callback null

    exports.testXhrServer = 'http://localhost:8911'
  else
    if typeof window is 'undefined' and typeof self isnt 'undefined'
      # Web Worker.
      exports = self
      exports.authDriver = null

      # NOTE: workers set testXhrServer in the "go" postMessage
      exports.testXhrServer = false
    else
      exports = window
      if cordova?
        # Cordova WebView.
        exports.authDriver = new Dropbox.AuthDriver.Cordova(
            rememberUser: false)

        # The XHR test server isn't available in Cordova.
        exports.testXhrServer = null
      else
        # Browser
        exports.authDriver = new Dropbox.AuthDriver.Popup(
            receiverFile: 'oauth_receiver.html', rememberUser: false,
            scope: 'helper-popup')

        # NOTE: not all browsers suppot location.origin, using our own helper
        exports.testXhrServer =
            Dropbox.AuthDriver.Popup.locationOrigin(exports.location)

  # NOTE: browser-side apps should not use API secrets, so we remove them
  exports.testKeys.__secret = exports.testKeys.secret
  delete exports.testKeys['secret']
  exports.testFullDropboxKeys.__secret = exports.testFullDropboxKeys.secret
  delete exports.testFullDropboxKeys['secret']

# Shared setup.
exports.assert = exports.chai.assert
exports.expect = exports.chai.expect
