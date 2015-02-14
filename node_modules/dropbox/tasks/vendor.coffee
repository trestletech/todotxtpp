async = require 'async'
fs = require 'fs'

download = require './download'

vendor = (callback) ->
  # All the files will be dumped here.
  fs.mkdirSync 'test/vendor' unless fs.existsSync 'test/vendor'

  # Embed the binary test image into a 7-bit ASCII JavaScript.
  buffer = fs.readFileSync 'test/binary/dropbox.png'
  bytes = (buffer.readUInt8(i) for i in [0...buffer.length])
  browserJs = "window.testImageBytes = [#{bytes.join(', ')}];\n"
  fs.writeFileSync 'test/vendor/favicon.browser.js', browserJs
  workerJs = "self.testImageBytes = [#{bytes.join(', ')}];\n"
  fs.writeFileSync 'test/vendor/favicon.worker.js', workerJs

  downloads = [
    # chai.js ships different builds for browsers vs node.js
    ['http://chaijs.com/chai.js', 'test/vendor/chai.js'],
    # sinon.js also ships special builds for browsers
    ['http://sinonjs.org/releases/sinon.js', 'test/vendor/sinon.js'],
    # ... and sinon.js ships an IE-only module
    ['http://sinonjs.org/releases/sinon-ie.js', 'test/vendor/sinon-ie.js']
  ]
  async.forEachSeries downloads, download, ->
    callback() if callback

module.exports = vendor
