express = require 'express'
fs = require 'fs'
http = require 'http'
https = require 'https'

# express.js app server for the Web files and XHR tests.
class WebFileServer
  # Starts up a HTTP server.
  constructor: (options = {}) ->
    @port = options.port or 8911
    @noSsl = !!options.noSsl
    @protocol = if @noSsl then 'http' else 'https'
    @createApp()

  # The root URL for XHR tests.
  testOrigin: ->
    "#{@protocol}://localhost:#{@port}"

  # The URL that should be used to start the tests.
  testUrl: ->
    "#{@protocol}://localhost:#{@port}/test/html/browser_test.html"

  # The URL that should be used to open the debugging environment.
  consoleUrl: ->
    "#{@protocol}://localhost:#{@port}/test/html/browser_console.html"

  # The self-signed certificate used by this server.
  certificate: ->
    return null unless @useHttps
    keyMaterial = fs.readFileSync 'test/ssl/cert.pem', 'utf8'
    certIndex = keyMaterial.indexOf '-----BEGIN CERTIFICATE-----'
    keyMaterial.substring certIndex

  # The server code.
  createApp: ->
    @app = express()

    ## Middleware.

    # CORS headers.
    @app.use (request, response, next) ->
      response.header 'Access-Control-Allow-Origin', '*'
      response.header 'Access-Control-Allow-Methods', 'DELETE,GET,POST,PUT'
      response.header 'Access-Control-Allow-Headers',
                      'Content-Type, Authorization'
      response.header 'Access-Control-Expose-Headers', 'x-dropbox-metadata'
      next()

    # Disable HTTP caching, for IE.
    @app.use (request, response, next) ->
      response.header 'Cache-Control', 'no-cache'
      # For IE. Invalid dates should be parsed as "already expired".
      response.header 'Expires', '-1'
      next()

    @app.use @app.router

    @app.use express.static(fs.realpathSync(__dirname + '/../../../'),
                            { hidden: true })

    ## Routes

    # Ends the tests.
    @app.get '/diediedie', (request, response) =>
      if 'failed' of request.query
        failed = parseInt request.query['failed']
      else
        failed = 1
      total = parseInt request.query['total'] || 0
      passed = total - failed
      exitCode = if failed == 0 then 0 else 1
      console.log "#{passed} passed, #{failed} failed"

      response.header 'Content-Type', 'image/png'
      response.header 'Content-Length', '0'
      response.end ''
      unless 'NO_EXIT' of process.env
        @server.close()
        process.exit exitCode

    # Simulate receiving an OAuth 2 access token.
    @app.post '/form_encoded', (request, response) ->
      body = 'access_token=test%20token&token_type=Bearer'
      contentType = 'application/x-www-form-urlencoded'
      if charset = request.param('charset')
        contentType += "; charset=#{charset}"
      response.header 'Content-Type', contentType
      response.header 'Content-Length', body.length.toString()
      response.end body

    # Simulate receiving user info.
    @app.post '/json_encoded', (request, response) ->
      body = JSON.stringify(
          uid: 42, country: 'US', display_name: 'John P. User')
      contentType = 'application/json'
      if charset = request.param('charset')
        contentType += "; charset=#{charset}"
      response.header 'Content-Type', contentType
      response.header 'Content-Length', body.length.toString()
      response.end body

    # Simulate reading a file.
    @app.get '/dropbox_file', (request, response) ->
      # Test Authorize and error handling.
      if request.get('Authorization') != 'Bearer mock00token'
        body = JSON.stringify error: 'invalid access token'
        response.status 401
        # NOTE: the API server uses text/javascript instead of application/json
        response.header 'Content-Type', 'text/javascript'
        response.header 'Content-Length', body.length
        response.end body
        return

      # Test metadata parsing.
      metadata = JSON.stringify(
          size: '1KB', is_dir: false, path: '/test_path.txt', root: 'dropbox')
      body = 'Test file contents'
      response.header 'Content-Type', 'text/plain'
      response.header 'X-Dropbox-Metadata', metadata
      response.header 'Content-Length', body.length
      response.end body

    # Simulate metadata bugs.
    @app.get '/dropbox_file_bug/:bug_id', (request, response) ->
      metadata = JSON.stringify(
          size: '1KB', is_dir: false, path: '/test_path.txt', root: 'dropbox')
      body = 'Test file contents'
      response.header 'Content-Type', 'text/plain'
      switch request.params.bug_id
        when '2x'
          response.header 'X-Dropbox-Metadata', "#{metadata}, #{metadata}"
        when 'txt'
          response.header 'X-Dropbox-Metadata', 'no json here'
      response.end body


    ## Server creation.

    if @noSsl
      @server = http.createServer @app
    else
      options = key: fs.readFileSync('test/ssl/cert.pem')
      options.cert = options.key
      @server = https.createServer options, @app
    @server.listen @port

module.exports = WebFileServer
