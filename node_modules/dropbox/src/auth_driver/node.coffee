# OAuth driver that redirects the browser to a node app to complete the flow.
#
# This is useful for testing node.js libraries and applications.
class Dropbox.AuthDriver.NodeServer
  # Starts up the node app that intercepts the browser redirect.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {Number} port the number of the TCP port that will receive
  #   HTTPS requests; defaults to 8912
  # @option options {Object} tls one or more of the options accepted by
  #   tls.createServer in the node.js standard library; at a minimum, the key
  #   option should be provided
  constructor: (options) ->
    @_port = options?.port or 8912
    if options?.tls
      @_tlsOptions  = options.tls
      if typeof @_tlsOptions is 'string' or @_tlsOptions instanceof Buffer
        @_tlsOptions = key: @_tlsOptions, cert: @_tlsOptions
    else
      @_tlsOptions = null
    # Calling require in the constructor because this doesn't work in browsers.
    @_fs = Dropbox.Env.require 'fs'
    @_http = Dropbox.Env.require 'http'
    @_https = Dropbox.Env.require 'https'
    @_open = Dropbox.Env.require 'open'

    @_callbacks = {}
    @_nodeUrl = Dropbox.Env.require 'url'
    @createApp()

  # The /authorize response type.
  authType: -> "code"

  # URL to the node.js OAuth callback handler.
  url: ->
    protocol = if @_tlsOptions is null then 'http' else 'https'
    "#{protocol}://localhost:#{@_port}/oauth_callback"

  # Opens the token
  doAuthorize: (authUrl, stateParam, client, callback) ->
    @_callbacks[stateParam] = callback
    @openBrowser authUrl

  # Opens the given URL in a browser.
  openBrowser: (url) ->
    unless url.match /^https?:\/\//
      throw new Error("Not a http/https URL: #{url}")
    if 'BROWSER' of process.env
      @_open url, process.env['BROWSER']
    else
      @_open url

  # Creates and starts up an HTTP server that will intercept the redirect.
  createApp: ->
    if @_tlsOptions
      @_app = @_https.createServer @_tlsOptions, (request, response) =>
        @doRequest request, response
    else
      @_app = @_http.createServer (request, response) =>
        @doRequest request, response
    @_app.listen @_port

  # Shuts down the HTTP server.
  #
  # The driver will become unusable after this call.
  closeServer: ->
    @_app.close()

  # Reads out an /authorize callback.
  doRequest: (request, response) ->
    url = @_nodeUrl.parse request.url, true
    if url.pathname is '/oauth_callback'
      stateParam = url.query.state
      if @_callbacks[stateParam]
        @_callbacks[stateParam](url.query)
        delete @_callbacks[stateParam]

    data = ''
    request.on 'data', (dataFragment) -> data += dataFragment
    request.on 'end', => @closeBrowser response

  # Renders a response that will close the browser window used for OAuth.
  closeBrowser: (response) ->
    closeHtml = """
                <!doctype html>
                <script type="text/javascript">window.close();</script>
                <p>Please close this window.</p>
                """
    response.writeHead(200,
        'Content-Length': closeHtml.length, 'Content-Type': 'text/html')
    response.write closeHtml
    response.end()
