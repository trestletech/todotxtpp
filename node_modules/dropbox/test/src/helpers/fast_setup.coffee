# Subset of the node.js branch in test/src/helpers/setup.coffee

require('source-map-support').install()

exports = global

exports.Dropbox = require '../../../lib/dropbox'
exports.chai = require 'chai'
exports.sinon = require 'sinon'
exports.sinonChai = require 'sinon-chai'

WebFileServer = require './web_file_server.js'
webFileServer = new WebFileServer()
exports.testXhrServer = webFileServer.testOrigin()

testImagePath = './test/binary/dropbox.png'
fs = require 'fs'
buffer = fs.readFileSync testImagePath
exports.testImageBytes = (buffer.readUInt8(i) for i in [0...buffer.length])


# Shared setup.
exports.assert = exports.chai.assert
exports.expect = exports.chai.expect
