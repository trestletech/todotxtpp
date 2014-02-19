async = require 'async'
fs = require 'fs'
glob = require 'glob'
path = require 'path'

run = require './run'

build = (callback) ->
  buildCode ->
    buildTests ->
      callback() if callback

buildCode = (callback) ->
  # Ignoring ".coffee" when sorting.
  # We want "auth_driver.coffee" to sort before "auth_driver/browser.coffee"
  source_files = glob.sync 'src/**/*.coffee'
  source_files.sort (a, b) ->
    a.replace(/\.coffee$/, '').localeCompare b.replace(/\.coffee$/, '')

  # TODO(pwnall): add --map after --compile when CoffeeScript #2779 is fixed
  #               and the .map file isn't useless
  command = 'node node_modules/coffee-script/bin/coffee --output lib ' +
      "--compile --join dropbox.js #{source_files.join(' ')}"

  run command, noExit: true, noOutput: true, (exitCode) ->
    if exitCode is 0
      callback() if callback
      return

    # The build failed.
    # Compile without --join for decent error messages.
    fs.mkdirSync 'tmp' unless fs.existsSync 'tmp'
    commands = []
    commands.push 'node node_modules/coffee-script/bin/coffee ' +
        '--output tmp --compile ' + source_files.join(' ')
    async.forEachSeries commands, run, ->
      # run should exit on its own. This is mostly for clarity.
      process.exit 1

buildTests = (callback) ->
  fs.mkdirSync 'test/js' unless fs.existsSync 'test/js'
  commands = []
  # Tests are supposed to be independent, so the build order doesn't matter.
  test_dirs = glob.sync 'test/src/**/'
  for test_dir in test_dirs
    out_dir = test_dir.replace(/^test\/src\//, 'test/js/')
    test_files = glob.sync path.join(test_dir, '*.coffee')
    commands.push "node node_modules/coffee-script/bin/coffee " +
                  "--output #{out_dir} --compile #{test_files.join(' ')}"
  async.forEachSeries commands, run, ->
    callback() if callback

buildPackage = (callback) ->
  # Minify the javascript, for browser distribution.
  commands = []
  commands.push 'cd lib && node ../node_modules/uglify-js/bin/uglifyjs ' +
      '--compress --mangle --output dropbox.min.js ' +
      '--source-map dropbox.min.map dropbox.js'
  async.forEachSeries commands, run, ->
    callback() if callback

module.exports = build
build.package = buildPackage
