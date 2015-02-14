async = require 'async'
fs = require 'fs-extra'
glob = require 'glob'
path = require 'path'
watch = require 'watch'

require 'coffee-script/register'
build = require './tasks/build'
clean = require './tasks/clean'
dconsole = require './tasks/dconsole'
download = require './tasks/download'
siteDoc = require './tasks/site_doc'
run = require './tasks/run'
test = require './tasks/test'
vendor = require './tasks/vendor'


# Node 0.6 compatibility hack.
unless fs.existsSync
  fs.existsSync = (filePath) -> path.existsSync filePath


task 'build', ->
  clean ->
    build ->
      build.package()

task 'clean', ->
  clean()

task 'watch', ->
  setupWatch()

task 'test', ->
  vendor ->
    build ->
      ssl_cert ->
        tokens ->
          test.node (code) ->
            process.exit code

task 'fasttest', ->
  clean ->
    build ->
      ssl_cert ->
        test.fast (code) ->
          process.exit code

task 'webtest', ->
  vendor ->
    build ->
      ssl_cert ->
        tokens ->
          test.web()

task 'webconsole', ->
  build ->
    build.package ->
      ssl_cert ->
        tokens ->
          dconsole.web()

task 'cert', ->
  fs.removeSync 'test/ssl' if fs.existsSync 'test/ssl'
  ssl_cert()

task 'vendor', ->
  fs.removeSync 'test/vendor' if fs.existsSync 'test/vendor'
  vendor()

task 'tokens', ->
  fs.removeSync 'test/token' if fs.existsSync 'test/token'
  build ->
    ssl_cert ->
      tokens ->
        process.exit 0

task 'doc', ->
  fs.mkdirSync 'doc' unless fs.existsSync 'doc'
  run 'node_modules/codo/bin/codo'

task 'devdoc', ->
  fs.mkdirSync 'doc' unless fs.existsSync 'doc'
  run 'node_modules/codo/bin/codo --private'

task 'sitedoc', ->
  fs.mkdir 'sitedoc' unless fs.existsSync 'sitedoc'
  fs.mkdir 'sitedoc/yaml' unless fs.existsSync 'sitedoc/yaml'
  run 'node_modules/codo/bin/codo --theme yaml --output-dir sitedoc/yaml', ->
    siteDoc 'sitedoc'


task 'extension', ->
  run 'node node_modules/coffee-script/bin/coffee ' +
      '--compile test/chrome_extension/*.coffee'

task 'chrome', ->
  vendor ->
    build ->
      buildChromeApp 'app_v1'

task 'chrome2', ->
  vendor ->
    build ->
      buildChromeApp 'app_v2'

task 'chrometest', ->
  vendor ->
    build ->
      buildChromeApp 'app_v1', ->
        testChromeApp ->
          process.exit 0

task 'chrometest2', ->
  vendor ->
    build ->
      buildChromeApp 'app_v2', ->
        testChromeApp ->
          process.exit 0

task 'cordova', ->
  platform = process.env['CORDOVA_PLATFORM'] or 'android'
  vendor ->
    build ->
      scaffoldCordovaApp platform, ->
        buildCordovaApp platform

task 'cordovatest', ->
  platform = process.env['CORDOVA_PLATFORM'] or 'android'
  vendor ->
    build ->
      scaffoldCordovaApp platform, ->
        buildCordovaApp platform, ->
          testCordovaApp platform

setupWatch = (callback) ->
  scheduled = true
  buildNeeded = true
  cleanNeeded = true
  onTick = ->
    scheduled = false
    if cleanNeeded
      buildNeeded = false
      cleanNeeded = false
      console.log "Doing a clean build"
      clean -> build -> test.fast()
    else if buildNeeded
      buildNeed = false
      console.log "Building"
      build -> test.fast()
  process.nextTick onTick

  watchMonitor = (monitor) ->
    monitor.on 'created', (fileName) ->
      return unless path.basename(fileName)[0] is '.'
      buildNeeded = true
      unless scheduled
        scheduled = true
        process.nextTick onTick
    monitor.on 'changed', (fileName) ->
      return unless path.basename(fileName)[0] is '.'
      buildNeeded = true
      unless scheduled
        scheduled = true
        process.nextTick onTick
    monitor.on 'removed', (fileName) ->
      return unless path.basename(fileName)[0] is '.'
      cleanNeeded = true
      buildNeeded = true
      unless scheduled
        scheduled = true
        process.nextTick onTick

  watch.createMonitor 'src/', watchMonitor
  watch.createMonitor 'test/src/', watchMonitor

ssl_cert = (callback) ->
  if fs.existsSync 'test/ssl/cert.pem'
    callback() if callback?
    return

  fs.mkdirSync 'test/ssl' unless fs.existsSync 'test/ssl'
  run 'openssl req -new -x509 -days 365 -nodes -batch ' +
      '-out test/ssl/cert.pem -keyout test/ssl/cert.pem ' +
      '-subj /O=dropbox.js/OU=Testing/CN=localhost ', callback

testChromeApp = (callback) ->
  # Set up the file server for XHR tests.
  WebFileServer = require './test/js/helpers/web_file_server.js'
  new WebFileServer port: 8911, noSsl: true

  # Clean up the profile.
  fs.mkdirSync 'test/chrome_profile' unless fs.existsSync 'test/chrome_profile'

  command = "\"#{chromeCommand()}\" " +
      '--load-extension=test/chrome_app ' +
      '--load-and-launch-app=test/chrome_app ' +
      '--user-data-dir=test/chrome_profile --no-default-browser-check ' +
      '--no-first-run --no-service-autorun --disable-default-apps ' +
      '--homepage=about:blank --v=-1 chrome://extensions'

  run command, ->
    callback() if callback

buildChromeApp = (manifestFile, callback) ->
  buildStandaloneApp "test/chrome_app", ->
    run "cp test/chrome_app/manifests/#{manifestFile}.json " +
        'test/chrome_app/manifest.json', ->
          callback() if callback

buildStandaloneApp = (appPath, callback) ->
  unless fs.existsSync appPath
    fs.mkdirSync appPath
  unless fs.existsSync "#{appPath}/test"
    fs.mkdirSync "#{appPath}/test"
  unless fs.existsSync "#{appPath}/node_modules"
    fs.mkdirSync "#{appPath}/node_modules"

  links = [
    ['lib', "#{appPath}/lib"],
    ['node_modules/mocha', "#{appPath}/node_modules/mocha"],
    ['node_modules/sinon-chai', "#{appPath}/node_modules/sinon-chai"],
    ['test/token', "#{appPath}/test/token"],
    ['test/binary', "#{appPath}/test/binary"],
    ['test/html', "#{appPath}/test/html"],
    ['test/js', "#{appPath}/test/js"],
    ['test/vendor', "#{appPath}/test/vendor"],
  ]
  commands = for link in links
    "cp -r #{link[0]} #{path.dirname(link[1])}"
  async.forEachSeries commands, run, ->
    callback() if callback

chromeCommand = ->
  paths = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
    '/Applications/Chromium.app/MacOS/Contents/Chromium',
  ]
  for path in paths
    return path if fs.existsSync path

  if process.platform is 'win32'
    'chrome'
  else
    'google-chrome'

testCordovaApp = (platform, callback) ->
  run 'cd test/cordova_app && ../../node_modules/cordova/bin/cordova ' +
      " run #{platform}", ->
    callback() if callback

scaffoldCordovaApp = (platform, callback) ->
  step1 = ->
    if fs.existsSync 'test/cordova_app'
      step2()
    else
      run 'node_modules/cordova/bin/cordova create test/cordova_app ' +
          'com.dropbox.js.tests "DropboxJsTests"', ->
        step2()
  step2 = ->
    commands = []
    unless fs.existsSync(
        'test/cordova_app/plugins/org.apache.cordova.core.inappbrowser')
      commands.push(
          'cd test/cordova_app && ../../node_modules/cordova/bin/cordova ' +
          'plugin add org.apache.cordova.inappbrowser')
    unless fs.existsSync "test/cordova_app/platforms/#{platform}"
      commands.push(
          'cd test/cordova_app && ../../node_modules/cordova/bin/cordova ' +
          "platform add #{platform}")
    if commands.length is 0
      callback() if callback
    else
      async.forEachSeries commands, run, ->
        callback() if callback

  step1()

buildCordovaApp = (platform, callback) ->
  buildStandaloneApp 'test/cordova_app/www', ->
    htmlFile = 'test/cordova_app/www/test/html/browser_test.html'
    testHtml = fs.readFileSync htmlFile, encoding: 'utf-8'
    testHtml = testHtml.replace(/<script src="[^"]*\/platform.js">/,
        '<script src="../../cordova.js">')
    fs.writeFileSync htmlFile, testHtml
    run "cp test/html/cordova_index.html test/cordova_app/www/index.html", ->
    run "cp test/html/cordova_index.html test/cordova_app/www/index.html", ->
      callback() if callback

tokens = (callback) ->
  TokenStash = require './test/js/helpers/token_stash.js'
  tokenStash = new TokenStash tls: fs.readFileSync('test/ssl/cert.pem')
  tokenStash.get ->
    callback() if callback?

