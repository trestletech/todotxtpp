# Represents a user accessing the application.
class Dropbox.Client
  # Dropbox API client representing an user or an application.
  #
  # For an optimal user experience, applications should use a single client for
  # all Dropbox interactions.
  #
  # @param {Object} options the application type and API key; alternatively,
  #   the result of a previous {Dropbox.Client#credentials} call can be passed
  #   in to create a {Dropbox.Client} instance for the same user
  # @option options {String} key the Dropbox application's key (client
  #   identifier, in OAuth 2.0 vocabulary)
  # @option options {String} secret the Dropbox application's secret (client
  #   secret, in OAuth 2.0 vocabulary); browser-side applications should not
  #   use this option
  # @option options {String} token (optional) the user's OAuth 2.0 access token
  # @option options {String} uid (optional) the user's Dropbox UID
  #
  # @see Dropbox.Client#credentials
  constructor: (options) ->
    @_serverRoot = options.server or @_defaultServerRoot()
    if 'maxApiServer' of options
      @_maxApiServer = options.maxApiServer
    else
      @_maxApiServer = @_defaultMaxApiServer()
    @_authServer = options.authServer or @_defaultAuthServer()
    @_fileServer = options.fileServer or @_defaultFileServer()
    @_downloadServer = options.downloadServer or @_defaultDownloadServer()
    @_notifyServer = options.notifyServer or @_defaultNotifyServer()

    @onXhr = new Dropbox.Util.EventSource cancelable: true
    @onError = new Dropbox.Util.EventSource
    @onAuthStepChange = new Dropbox.Util.EventSource
    @_xhrOnErrorHandler = (error, callback) => @_handleXhrError error, callback

    @_oauth = new Dropbox.Util.Oauth options
    @_uid = options.uid or null
    @authStep = @_oauth.step()
    @_driver = null
    @authError = null
    @_credentials = null

    @setupUrls()

  # @property {Dropbox.Util.EventSource<Dropbox.Util.Xhr>} fires cancelable
  #   events every time when a network request to the Dropbox API server is
  #   about to be sent; if the event is canceled by returning a falsey value
  #   from a listener, the network request is silently discarded; whenever
  #   possible, listeners should restrict themselves to using the xhr property
  #   of the {Dropbox.Util.Xhr} instance passed to them; everything else in the
  #   {Dropbox.Util.Xhr} API is in flux
  onXhr: null

  # @property {Dropbox.Util.EventSource<Dropbox.ApiError>} fires non-cancelable
  #   events every time when a network request to the Dropbox API server
  #   results in an error
  onError: null

  # @property {Dropbox.Util.EventSource<Dropbox.Client>} fires non-cancelable
  #   events every time this client's authStep property changes; this can be
  #   used to update UI state
  onAuthStepChange: null

  # Plugs in the OAuth / application integration code.
  #
  # This replaces any driver set up by previous calls to
  # {Dropbox.Client#authDriver}. On most supported platforms, an OAuth driver
  # can be configured automatically.
  #
  # @param {Dropbox.AuthDriver} driver provides the integration between the
  #   application and the OAuth 2.0 flow used by the Dropbox API
  # @return {Dropbox.Client} this, for easy call chaining
  authDriver: (driver) ->
    @_driver = driver
    @

  # The authenticated user's Dropbx user account ID.
  #
  # This user account ID is guaranteed to be consistent across API calls from
  # the same application (not across applications, though).
  #
  # @return {String} a short ID that identifies the user account; null if no
  #   user is authenticated
  dropboxUid: ->
    @_uid

  # Get the client's OAuth credentials.
  #
  # @return {Object} a plain object whose properties can be passed to
  #   {Dropbox.Client#setCredentials} or to the {Dropbox.Client} constructor to
  #   reuse this client's login credentials
  credentials: ->
    @_computeCredentials() unless @_credentials
    @_credentials

  # Authenticates the app's user to Dropbox's API server.
  #
  # In most cases, the process will involve sending the user to an
  # authorization server on the Dropbox servers. If the user clicks "Allow",
  # the application will be authorized. If the user clicks "Deny", the method
  # will pass a {Dropbox.AuthError} to its callback, and the error's code will
  # be {Dropbox.AuthError.ACCESS_DENIED}.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {Boolean} interactive if false, the authentication process
  #   will stop and call the callback whenever it would have to wait for an
  #   authorization; true by default; this is useful for determining if the
  #   authDriver has cached credentials available
  # @param {function(Dropbox.ApiError|Dropbox.AuthError, Dropbox.Client)}
  #   callback (optional) called when the authentication completes; if
  #   successful, the second parameter is this client and the first parameter
  #   is null
  # @return {Dropbox.Client} this, for easy call chaining
  authenticate: (options, callback) ->
    if !callback and typeof options is 'function'
      callback = options
      options = null

    if options and 'interactive' of options
      interactive = options.interactive
    else
      interactive = true

    unless @_driver or @authStep is DbxClient.DONE
      Dropbox.AuthDriver.autoConfigure @
      unless @_driver
        throw new Error(
            'OAuth driver auto-configuration failed. Call authDriver.')

    if @authStep is DbxClient.ERROR
      throw new Error 'Client got in an error state. Call reset() to reuse it!'


    # _fsmStep helper that transitions the FSM to the next step.
    # This is repetitive stuff done at the end of each step.
    _fsmNextStep = =>
      @authStep = @_oauth.step()
      @authError = @_oauth.error() if @authStep is DbxClient.ERROR
      @_credentials = null
      @onAuthStepChange.dispatch @
      _fsmStep()

    # _fsmStep helper that transitions the FSM to the error step.
    _fsmErrorStep = =>
      @authStep = DbxClient.ERROR
      @_credentials = null
      @onAuthStepChange.dispatch @
      _fsmStep()

    # Advances the authentication FSM by one step.
    oldAuthStep = null
    _fsmStep = =>
      if oldAuthStep isnt @authStep
        oldAuthStep = @authStep
        if @_driver and @_driver.onAuthStepChange
          @_driver.onAuthStepChange(@, _fsmStep)
          return

      switch @authStep
        when DbxClient.RESET
          # No credentials. Decide on a state param for OAuth 2 authorization.
          unless interactive
            callback null, @ if callback
            return
          if @_driver.getStateParam
            @_driver.getStateParam (stateParam) =>
              # NOTE: the driver might have injected the state param itself
              if @client.authStep is DbxClient.RESET
                @_oauth.setAuthStateParam stateParam
              _fsmNextStep()
          @_oauth.setAuthStateParam Dropbox.Util.Oauth.randomAuthStateParam()
          _fsmNextStep()

        when DbxClient.PARAM_SET
          # Ask the user for authorization.
          unless interactive
            callback null, @ if callback
            return
          authUrl = @authorizeUrl()
          @_driver.doAuthorize authUrl, @_oauth.authStateParam(), @,
              (queryParams) =>
                @_oauth.processRedirectParams queryParams
                @_uid = queryParams.uid if queryParams.uid
                _fsmNextStep()

        when DbxClient.PARAM_LOADED
          # Check a previous state parameter.
          unless @_driver.resumeAuthorize
            # This switches the client to the PARAM_SET state
            @_oauth.setAuthStateParam @_oauth.authStateParam()
            _fsmNextStep()
            return
          @_driver.resumeAuthorize @_oauth.authStateParam(), @,
              (queryParams) =>
                @_oauth.processRedirectParams queryParams
                @_uid = queryParams.uid if queryParams.uid
                _fsmNextStep()

        when DbxClient.AUTHORIZED
          # Request token authorized, switch it for an access token.
          @getAccessToken (error, data) =>
            if error
              @authError = error
              _fsmErrorStep()
            else
              @_oauth.processRedirectParams data
              @_uid = data.uid
              _fsmNextStep()

        when DbxClient.DONE  # We have an access token.
            callback null, @ if callback
            return

        when DbxClient.SIGNED_OUT  # The user signed out, restart the flow.
          # The authStep change makes reset() not trigger onAuthStepChange.
          @authStep = DbxClient.RESET
          @reset()
          _fsmStep()

        when DbxClient.ERROR  # An error occurred during authentication.
          callback @authError, @ if callback
          return

    _fsmStep()  # Start up the state machine.
    @

  # Checks if this client can perform API calls on behalf of a user.
  #
  # @return {Boolean} true if this client has a user's OAuth 2 access token and
  #   can be used to make API calls; false otherwise
  isAuthenticated: ->
    @authStep is DbxClient.DONE

  # Invalidates and forgets the user's Dropbox OAuth 2 access token.
  #
  # This should be called when the user explicitly signs off from your
  # application, to meet the users' expectation that after they sign out, their
  # access tokens will not be persisted on the machine.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {Boolean} mustInvalidate when true, the method will fail if
  #   the API call for invalidating the token fails; by default, the access
  #   token is forgotten and the method reports success even if the API call
  #   fails
  # @param {function(Dropbox.ApiError)} callback called after the user's
  #   token is forgotten; if successful, the error parameter is null; this
  #   method will always succeed if mustInvalidate isn't true
  # @return {XMLHttpRequest} the XHR object used for this API call
  # @throw {Error} if this client doesn't have Dropbox credentials associated
  #   with it; call {Dropbox.Client#isAuthenticated} to find out if a client
  #   has credentials
  # @see Dropbox.Client#isAuthenticated
  signOut: (options, callback) ->
    if !callback and typeof options is 'function'
      callback = options
      options = null

    stopOnXhrError = options and options.mustInvalidate
    unless @authStep is DbxClient.DONE
      throw new Error("This client doesn't have a user's token")

    xhr = new Dropbox.Util.Xhr 'POST', @_urls.signOut
    xhr.signWithOauth @_oauth
    @_dispatchXhr xhr, (error) =>
      if error
        if error.status is Dropbox.ApiError.INVALID_TOKEN
          # The token was already invalidated. Sweet.
          error = null
        else if stopOnXhrError
          callback error if callback
          return

      # The authStep change makes reset() not trigger onAuthStepChange.
      @authStep = DbxClient.RESET
      @reset()
      @authStep = DbxClient.SIGNED_OUT
      @onAuthStepChange.dispatch @
      if @_driver and @_driver.onAuthStepChange
        @_driver.onAuthStepChange @, ->
          callback null if callback
      else
        callback null if callback

  # Alias for signOut.
  #
  # @see Dropbox.Client#signOut
  signOff: (options, callback) ->
    @signOut options, callback

  # Retrieves information about the logged in user.
  #
  # @param {Object} options (optional) the advanced settings below
  # @option options {Boolean} httpCache if true, the API request will be set to
  #   allow HTTP caching to work; by default, requests are set up to avoid
  #   CORS preflights; setting this option can make sense when making the same
  #   request repeatedly
  # @param {function(Dropbox.ApiError, Dropbox.AccountInfo, Object)} callback
  #   called with the result of the /account/info HTTP request; if the call
  #   succeeds, the second parameter is a {Dropbox.AccountInfo} instance, the
  #   third parameter is the parsed JSON data behind the {Dropbox.AccountInfo}
  #   instance, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  getAccountInfo: (options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    httpCache = false
    if options and options.httpCache
      httpCache = true

    xhr = new Dropbox.Util.Xhr 'GET', @_urls.accountInfo
    xhr.signWithOauth @_oauth, httpCache
    @_dispatchXhr xhr, (error, accountData) ->
      callback error, Dropbox.AccountInfo.parse(accountData), accountData

  # Backwards-compatible name of getAccountInfo.
  #
  # @deprecated
  # @see Dropbox.Client#getAccountInfo
  getUserInfo: (options, callback) ->
    @getAccountInfo options, callback

  # Retrieves the contents of a file stored in Dropbox.
  #
  # Some options are silently ignored in Internet Explorer 9 and below, due to
  # insufficient support in its proprietary XDomainRequest replacement for XHR.
  # Currently, the options are: arrayBuffer, blob, length, start.
  #
  # @param {String} path the path of the file to be read, relative to the
  #   user's Dropbox or to the application's folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} versionTag the tag string for the desired version
  #   of the file contents; the most recent version is retrieved by default
  # @option options {String} rev alias for "versionTag" that matches the HTTP
  #   API
  # @option options {Boolean} arrayBuffer if true, the file's contents  will be
  #   passed to the callback in an ArrayBuffer; this is the recommended method
  #   of reading non-UTF8 data such as images, as it is well supported across
  #   modern browsers; requires XHR Level 2 support, which is not available in
  #   IE <= 9
  # @option options {Boolean} blob if true, the file's contents  will be
  #   passed to the callback in a Blob; this is a good method of reading
  #   non-UTF8 data, such as images; requires XHR Level 2 support, which is not
  #   available in IE <= 9
  # @option options {Boolean} buffer if true, the file's contents  will be
  #   passed to the callback in a node.js Buffer; this only works on node.js
  # @option options {Boolean} binary if true, the file will be retrieved as a
  #   binary string; the default is an UTF-8 encoded string; this relies on
  #   hacks and should not be used if the environment supports XHR Level 2 API
  # @option options {Number} length the number of bytes to be retrieved from
  #   the file; if the start option is not present, the last "length" bytes
  #   will be read; by default, the entire file is read
  # @option options {Number} start the 0-based offset of the first byte to be
  #   retrieved; if the length option is not present, the bytes between
  #   "start" and the file's end will be read; by default, the entire
  #   file is read
  # @option options {Boolean} httpCache if true, the API request will be set to
  #   allow HTTP caching to work; by default, requests are set up to avoid
  #   CORS preflights; setting this option can make sense when making the same
  #   request repeatedly
  # @param {function(Dropbox.ApiError, String, Dropbox.File.Stat,
  #   Dropbox.Http.RangeInfo)} callback called with the result of
  #   the /files (GET) HTTP request; the second parameter is the contents of
  #   the file, the third parameter is a {Dropbox.File.Stat} instance
  #   describing the file, and the first parameter is null; if the start
  #   and/or length options are specified, the fourth parameter describes the
  #   subset of bytes read from the file
  # @return {XMLHttpRequest} the XHR object used for this API call
  readFile: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    params = {}
    responseType = 'text'
    rangeHeader = null
    httpCache = false
    if options
      if options.versionTag
        params.rev = options.versionTag
      else if options.rev
        params.rev = options.rev

      if options.arrayBuffer
        responseType = 'arraybuffer'
      else if options.blob
        responseType = 'blob'
      else if options.buffer
        responseType = 'buffer'
      else if options.binary
        responseType = 'b'  # See the Dropbox.Util.Xhr.setResponseType docs

      if options.length
        if options.start?
          rangeStart = options.start
          rangeEnd = options.start + options.length - 1
        else
          rangeStart = ''
          rangeEnd = options.length
        rangeHeader = "bytes=#{rangeStart}-#{rangeEnd}"
      else if options.start?
        rangeHeader = "bytes=#{options.start}-"

      httpCache = true if options.httpCache

    xhr = new Dropbox.Util.Xhr 'GET',
                               "#{@_urls.getFile}/#{@_urlEncodePath(path)}"
    xhr.setParams(params).signWithOauth @_oauth, httpCache
    xhr.setResponseType responseType
    if rangeHeader
      xhr.setHeader 'Range', rangeHeader if rangeHeader
      xhr.reportResponseHeaders()
    @_dispatchXhr xhr, (error, data, metadata, headers) ->
      if headers
        rangeInfo = Dropbox.Http.RangeInfo.parse headers['content-range']
      else
        rangeInfo = null
      callback error, data, Dropbox.File.Stat.parse(metadata), rangeInfo

  # Store a file into a user's Dropbox.
  #
  # @param {String} path the path of the file to be created, relative to the
  #   user's Dropbox or to the application's folder
  # @param {String, ArrayBuffer, ArrayBufferView, Blob, File, Buffer} data the
  #   contents written to the file; if a File is passed, its name is ignored
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} lastVersionTag the identifier string for the
  #   version of the file's contents that was last read by this program, used
  #   for conflict resolution; for best results, use the versionTag attribute
  #   value from the Dropbox.File.Stat instance provided by readFile
  # @option options {String} parentRev alias for "lastVersionTag" that matches
  #   the HTTP API
  # @option options {Boolean} noOverwrite if set, the write will not overwrite
  #   a file with the same name that already exists; instead the contents will
  #   be written to a similarly named file (e.g. "notes (1).txt" instead of
  #   "notes.txt")
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat)} callback called
  #   with the result of the /files (POST) HTTP request; the second parameter
  #   is a {Dropbox.File.Stat} instance describing the newly created file, and
  #   the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  writeFile: (path, data, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    useForm = Dropbox.Util.Xhr.canSendForms and typeof data is 'object'
    if useForm
      @_writeFileUsingForm path, data, options, callback
    else
      @_writeFileUsingPut path, data, options, callback

  # writeFile implementation that uses the POST /files API.
  #
  # @private
  # Use {Dropbox.Client#writeFile} instead of calling this directly.
  #
  # This method is more demanding in terms of CPU and browser support, but does
  # not require CORS preflight, so it always completes in 1 HTTP request.
  _writeFileUsingForm: (path, data, options, callback) ->
    # Break down the path into a file/folder name and the containing folder.
    slashIndex = path.lastIndexOf '/'
    if slashIndex is -1
      fileName = path
      path = ''
    else
      fileName = path.substring slashIndex
      path = path.substring 0, slashIndex

    params = { file: fileName }
    if options
      if options.noOverwrite
        params.overwrite = 'false'
      if options.lastVersionTag
        params.parent_rev = options.lastVersionTag
      else if options.parentRev or options.parent_rev
        params.parent_rev = options.parentRev or options.parent_rev
    # TODO: locale support would edit the params here

    xhr = new Dropbox.Util.Xhr 'POST',
                               "#{@_urls.postFile}/#{@_urlEncodePath(path)}"
    xhr.setParams(params).signWithOauth(@_oauth).setFileField('file', fileName,
        data, 'application/octet-stream')

    # NOTE: the Dropbox API docs ask us to replace the 'file' parameter after
    #       signing the request; the hack below works as intended
    delete params.file

    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # writeFile implementation that uses the /files_put API.
  #
  # @private
  # Use {Dropbox.Client#writeFile} instead of calling this directly.
  #
  # This method is less demanding on CPU, and makes fewer assumptions about
  # browser support, but it takes 2 HTTP requests for binary files, because it
  # needs CORS preflight.
  _writeFileUsingPut: (path, data, options, callback) ->
    params = {}
    if options
      if options.noOverwrite
        params.overwrite = 'false'
      if options.lastVersionTag
        params.parent_rev = options.lastVersionTag
      else if options.parentRev or options.parent_rev
        params.parent_rev = options.parentRev or options.parent_rev
    # TODO: locale support would edit the params here
    xhr = new Dropbox.Util.Xhr 'POST',
                               "#{@_urls.putFile}/#{@_urlEncodePath(path)}"
    xhr.setBody(data).setParams(params).signWithOauth @_oauth
    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # Atomic step in a resumable file upload.
  #
  # @param {String, ArrayBuffer, ArrayBufferView, Blob, File, Buffer} data the
  #   file contents fragment to be uploaded; if a File is passed, its name is
  #   ignored
  # @param {Dropbox.Http.UploadCursor} cursor (optional) the cursor that tracks
  #   the state of the resumable file upload; the cursor information will not
  #   be updated when the API call completes
  # @param {function(Dropbox.ApiError, Dropbox.Http.UploadCursor)} callback
  #   called with the result of the /chunked_upload HTTP request; the second
  #   parameter is a {Dropbox.Http.UploadCursor} instance describing the
  #   progress of the upload operation, and the first parameter is null if no
  #   error occurs
  # @return {XMLHttpRequest} the XHR object used for this API call
  resumableUploadStep: (data, cursor, callback) ->
    if cursor
      params = { offset: cursor.offset }
      params.upload_id = cursor.tag if cursor.tag
    else
      params = { offset: 0 }

    xhr = new Dropbox.Util.Xhr 'POST', @_urls.chunkedUpload
    xhr.setBody(data).setParams(params).signWithOauth(@_oauth)
    @_dispatchXhr xhr, (error, cursor) ->
      if error and error.status is Dropbox.ApiError.INVALID_PARAM and
          error.response and error.response.upload_id and error.response.offset
        callback null, Dropbox.Http.UploadCursor.parse(error.response)
      else
        callback error, Dropbox.Http.UploadCursor.parse(cursor)

  # Finishes a resumable file upload.
  #
  # @param {String} path the path of the file to be created, relative to the
  #   user's Dropbox or to the application's folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} lastVersionTag the identifier string for the
  #   version of the file's contents that was last read by this program, used
  #   for conflict resolution; for best results, use the versionTag attribute
  #   value from the Dropbox.File.Stat instance provided by readFile
  # @option options {String} parentRev alias for "lastVersionTag" that matches
  #   the HTTP API
  # @option options {Boolean} noOverwrite if set, the write will not overwrite
  #   a file with the same name that already exists; instead the contents will
  #   be written to a similarly named file (e.g. "notes (1).txt" instead of
  #   "notes.txt")
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat)} callback called with
  #   the result of the /files (POST) HTTP request; the second parameter is a
  #   {Dropbox.File.Stat} instance describing the newly created file, and the
  #   first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  resumableUploadFinish: (path, cursor, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    params = { upload_id: cursor.tag }

    if options
      if options.lastVersionTag
        params.parent_rev = options.lastVersionTag
      else if options.parentRev or options.parent_rev
        params.parent_rev = options.parentRev or options.parent_rev
      if options.noOverwrite
        params.overwrite = 'false'

    # TODO: locale support would edit the params here
    xhr = new Dropbox.Util.Xhr 'POST',
        "#{@_urls.commitChunkedUpload}/#{@_urlEncodePath(path)}"
    xhr.setParams(params).signWithOauth(@_oauth)
    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # Reads the metadata of a file or folder in a user's Dropbox.
  #
  # @param {String} path the path to the file or folder whose metadata will be
  #   read, relative to the user's Dropbox or to the application's folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {Number} version if set, the call will return the metadata
  #   for the given revision of the file / folder; the latest version is used
  #   by default
  # @option options {Boolean} removed if set to true, the results will include
  #   files and folders that were deleted from the user's Dropbox
  # @option options {Boolean} deleted alias for "removed" that matches the HTTP
  #   API; using this alias is not recommended, because it may cause confusion
  #   with JavaScript's delete operation
  # @option options {Boolean, Number} readDir only meaningful when stat-ing
  #   folders; if this is set, the API call will also retrieve the folder's
  #   contents, which is passed into the callback's third parameter; if this
  #   is a number, it specifies the maximum number of files and folders that
  #   should be returned; the default limit is 10,000 items; if the limit is
  #   exceeded, the call will fail with an error
  # @option options {String} versionTag the tag string for the desired version
  #   of the file or folder metadata; the most recent version is retrieved by
  #   default
  # @option options {String} rev alias for "versionTag" that matches the HTTP
  #   API
  # @option options {String} contentHash used for saving bandwidth when getting
  #   a folder's contents; if this value is specified and it matches the
  #   folder's contents, the call will fail with a
  #   {Dropbox.ApiError.NO_CONTENT} error status; a folder's version identifier
  #   can be obtained from the {Dropbox.File.Stat#contentHash} property of the
  #   Stat instance describing the folder
  # @option options {String} hash alias for "contentHash" that matches the HTTP
  #   API
  # @option options {Boolean} httpCache if true, the API request will be set to
  #   allow HTTP caching to work; by default, requests are set up to avoid
  #   CORS preflights; setting this option can make sense when making the same
  #   request repeatedly
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat,
  #   Array<Dropbox.File.Stat>)} callback called with the result of the
  #   /metadata HTTP request; if the call succeeds, the second parameter is a
  #   {Dropbox.File.Stat} instance describing the file / folder, and the first
  #   parameter is null; if the readDir option is true and the call succeeds,
  #   the third parameter is an array of {Dropbox.File.Stat} instances
  #   describing the folder's entries
  # @return {XMLHttpRequest} the XHR object used for this API call
  stat: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    params = {}
    httpCache = false
    if options
      if options.versionTag
        params.rev = options.versionTag
      else if options.rev
        params.rev = options.rev
      if options.contentHash
        params.hash = options.contentHash
      else if options.hash
        params.hash = options.hash
      if options.removed or options.deleted
        params.include_deleted = 'true'
      if options.readDir
        params.list = 'true'
        if options.readDir isnt true
          params.file_limit = options.readDir.toString()
      if options.cacheHash
        params.hash = options.cacheHash
      if options.httpCache
        httpCache = true
    params.include_deleted ||= 'false'
    params.list ||= 'false'
    # TODO: locale support would edit the params here
    xhr = new Dropbox.Util.Xhr 'GET',
                               "#{@_urls.metadata}/#{@_urlEncodePath(path)}"
    xhr.setParams(params).signWithOauth @_oauth, httpCache
    @_dispatchXhr xhr, (error, metadata) ->
      stat = Dropbox.File.Stat.parse metadata
      if metadata?.contents
        entries = for entry in metadata.contents
          Dropbox.File.Stat.parse(entry)
      else
        entries = undefined
      callback error, stat, entries

  # Lists the files and folders inside a folder in a user's Dropbox.
  #
  # @param {String} path the path to the folder whose contents will be
  #   retrieved, relative to the user's Dropbox or to the application's
  #   folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {Boolean} removed if set to true, the results will include
  #   files and folders that were deleted from the user's Dropbox
  # @option options {Boolean} deleted alias for "removed" that matches the HTTP
  #   API; using this alias is not recommended, because it may cause confusion
  #   with JavaScript's delete operation
  # @option options {Boolean, Number} limit the maximum number of files and
  #   folders that should be returned; the default limit is 10,000 items; if
  #   the limit is exceeded, the call will fail with an error
  # @option options {String} versionTag the tag string for the desired version
  #   of the file or folder metadata; the most recent version is retrieved by
  #   default
  # @option options {String} contentHash used for saving bandwidth when getting
  #   a folder's contents; if this value is specified and it matches the
  #   folder's contents, the call will fail with a
  #   {Dropbox.ApiError.NO_CONTENT} error status; a folder's version identifier
  #   can be obtained from the {Dropbox.File.Stat#contentHash} property of the
  #   Stat instance describing the folder
  # @option options {Boolean} httpCache if true, the API request will be set to
  #   allow HTTP caching to work; by default, requests are set up to avoid
  #   CORS preflights; setting this option can make sense when making the same
  #   request repeatedly
  # @param {function(Dropbox.ApiError, Array<String>, Dropbox.File.Stat,
  #   Array<Dropbox.File.Stat>)} callback called with the result of the
  #   /metadata HTTP request; if the call succeeds, the second parameter is an
  #   array containing the names of the files and folders in the given folder,
  #   the third parameter is a {Dropbox.File.Stat} instance describing the
  #   folder, the fourth parameter is an array of {Dropbox.File.Stat} instances
  #   describing the folder's entries, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  readdir: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    statOptions = { readDir: true }
    if options
      if options.limit?
        statOptions.readDir = options.limit
      if options.versionTag
        statOptions.versionTag = options.versionTag
      else if options.rev
        statOptions.versionTag = options.rev
      if options.contentHash
        statOptions.contentHash = options.contentHash
      else if options.hash
        statOptions.contentHash = options.hash
      if options.removed or options.deleted
        statOptions.removed = options.removed or options.deleted
      if options.httpCache
        statOptions.httpCache = options.httpCache
    @stat path, statOptions, (error, stat, entry_stats) ->
      if entry_stats
        entries = (entry_stat.name for entry_stat in entry_stats)
      else
        entries = null
      callback error, entries, stat, entry_stats

  # Alias for "stat" that matches the HTTP API.
  #
  # @see Dropbox.Client#stat
  metadata: (path, options, callback) ->
    @stat path, options, callback

  # Creates a publicly readable URL to a file or folder in the user's Dropbox.
  #
  # @param {String} path the path to the file or folder that will be linked to;
  #   the path is relative to the user's Dropbox or to the application's
  #   folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {Boolean} download if set, the URL will be a direct
  #   download URL, instead of the usual Dropbox preview URLs; direct
  #   download URLs are short-lived (currently 4 hours), whereas regular URLs
  #   virtually have no expiration date (currently set to 2030); no direct
  #   download URLs can be generated for directories
  # @option options {Boolean} downloadHack if set, a long-living download URL
  #   will be generated by asking for a preview URL and using the officially
  #   documented hack at https://www.dropbox.com/help/201 to turn the preview
  #   URL into a download URL
  # @option options {Boolean} long if set, the URL will not be shortened using
  #   Dropbox's shortner; the download and downloadHack options imply long
  # @option options {Boolean} longUrl synonym for long; makes life easy for
  #   RhinoJS users
  # @param {function(Dropbox.ApiError, Dropbox.File.ShareUrl)} callback called
  #   with the result of the /shares or /media HTTP request; if the call
  #   succeeds, the second parameter is a {Dropbox.File.ShareUrl} instance,
  #   and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  makeUrl: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    # NOTE: cannot use options.long; normally, the CoffeeScript compiler
    #       escapes keywords for us; although long isn't really a keyword, the
    #       Rhino VM thinks it is; this hack can be removed when the bug below
    #       is fixed:
    #       https://github.com/mozilla/rhino/issues/93
    if options and (options['long'] or options.longUrl or options.downloadHack)
      params = { short_url: 'false' }
    else
      params = {}

    path = @_urlEncodePath path
    url = "#{@_urls.shares}/#{path}"
    isDirect = false
    useDownloadHack = false
    if options
      if options.downloadHack
        isDirect = true
        useDownloadHack = true
      else if options.download
        isDirect = true
        url = "#{@_urls.media}/#{path}"

    # TODO: locale support would edit the params here
    xhr = new Dropbox.Util.Xhr('POST', url).setParams(params).
                                            signWithOauth @_oauth
    @_dispatchXhr xhr, (error, urlData) =>
      if useDownloadHack and urlData?.url
        urlData.url = urlData.url.replace @_authServer, @_downloadServer
      callback error, Dropbox.File.ShareUrl.parse(urlData, isDirect)

  # Retrieves the revision history of a file in a user's Dropbox.
  #
  # @param {String} path the path to the file whose revision history will be
  #   retrieved, relative to the user's Dropbox or to the application's
  #   folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {Number} limit if specified, the call will return at most
  #   this many versions
  # @option options {Boolean} httpCache if true, the API request will be set to
  #   allow HTTP caching to work; by default, requests are set up to avoid
  #   CORS preflights; setting this option can make sense when making the same
  #   request repeatedly
  # @param {function(Dropbox.ApiError, Array<Dropbox.File.Stat>)} callback
  #   called with the result of the /revisions HTTP request; if the call
  #   succeeds, the second parameter is an array with one {Dropbox.File.Stat}
  #   instance per file version, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  history: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    params = {}
    httpCache = false
    if options
      if options.limit?
        params.rev_limit = options.limit
      if options.httpCache
        httpCache = true

    xhr = new Dropbox.Util.Xhr 'GET',
                               "#{@_urls.revisions}/#{@_urlEncodePath(path)}"
    xhr.setParams(params).signWithOauth @_oauth, httpCache
    @_dispatchXhr xhr, (error, versions) ->
      if versions
        stats = (Dropbox.File.Stat.parse(metadata) for metadata in versions)
      else
        stats = undefined
      callback error, stats

  # Alias for "history" that matches the HTTP API.
  #
  # @see Dropbox.Client#history
  revisions: (path, options, callback) ->
    @history path, options, callback

  # Computes a URL that generates a thumbnail for a file in the user's Dropbox.
  #
  # @param {String} path the path to the file whose thumbnail image URL will be
  #   computed, relative to the user's Dropbox or to the application's
  #   folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {Boolean} png if true, the thumbnail's image will be a PNG
  #   file; the default thumbnail format is JPEG
  # @option options {String} format value that gets passed directly to the API;
  #   this is intended for newly added formats that the API may not support;
  #   use options such as "png" when applicable
  # @option options {String} size specifies the image's dimensions; this
  #   gets passed directly to the API; currently, the following values are
  #   supported: 'small' (32x32), 'medium' (64x64), 'large' (128x128),
  #   's' (64x64), 'm' (128x128), 'l' (640x480), 'xl' (1024x768); the default
  #   value is "small"
  # @return {String} a URL to an image that can be used as the thumbnail for
  #   the given file
  thumbnailUrl: (path, options) ->
    xhr = @thumbnailXhr path, options
    xhr.addOauthParams(@_oauth).paramsToUrl().url

  # Retrieves the image data of a thumbnail for a file in the user's Dropbox.
  #
  # This method is intended to be used with low-level painting APIs. Whenever
  # possible, it is easier to place the result of thumbnailUrl in a DOM
  # element, and rely on the browser to fetch the file.
  #
  # @param {String} path the path to the file whose thumbnail image URL will be
  #   computed, relative to the user's Dropbox or to the application's
  #   folder
  # @param {Object} options (optional) one or more of the options below
  # @option options {Boolean} png if true, the thumbnail's image will be a PNG
  #   file; the default thumbnail format is JPEG
  # @option options {String} format value that gets passed directly to the API;
  #   this is intended for newly added formats that the API may not support;
  #   use options such as "png" when applicable
  # @option options {String} size specifies the image's dimensions; this
  #   gets passed directly to the API; currently, the following values are
  #   supported: 'small' (32x32), 'medium' (64x64), 'large' (128x128),
  #   's' (64x64), 'm' (128x128), 'l' (640x480), 'xl' (1024x768); the default
  #   value is "small"
  # @option options {Boolean} arrayBuffer if true, the file's contents  will be
  #   passed to the callback in an ArrayBuffer; this is the recommended method
  #   of reading thumbnails, as it is well supported across modern browsers;
  #   requires XHR Level 2 support, which is not available in IE <= 9
  # @option options {Boolean} blob if true, the file's contents  will be
  #   passed to the callback in a Blob; requires XHR Level 2 support, which is
  #   not available in IE <= 9
  # @option options {Boolean} buffer if true, the file's contents  will be
  #   passed to the callback in a node.js Buffer; this only works on node.js
  # @param {function(?Dropbox.ApiError, String|Blob, Dropbox.File.Stat)}
  #   callback called with the result of the /thumbnails HTTP request; if the
  #   call succeeds, the second parameter is the image data as a String or
  #   Blob, the third parameter is a {Dropbox.File.Stat} instance describing
  #   the thumbnailed file, and the first argument is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  readThumbnail: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    responseType = 'b'
    if options
      responseType = 'blob' if options.blob
      responseType = 'arraybuffer' if options.arrayBuffer
      responseType = 'buffer' if options.buffer

    xhr = @thumbnailXhr path, options
    xhr.setResponseType(responseType).signWithOauth(@_oauth)
    @_dispatchXhr xhr, (error, data, metadata) ->
      callback error, data, Dropbox.File.Stat.parse(metadata)

  # Sets up an XHR for reading a thumbnail for a file in the user's Dropbox.
  #
  # @private
  # Call {Dropbox.Client#thumbnailUrl} or {Dropbox.Client#readThumbnail}
  # instead of using this directly.
  #
  # @see Dropbox.Client#thumbnailUrl
  # @return {Dropbox.Util.Xhr} an XMLHttpRequest wrapper configured for
  #   fetching the thumbnail; the {Dropbox.Util.Xhr} instance does not have
  #   OAuth credentials applied to it, and the caller is responsible for
  #   calling {Dropbox.Util.Xhr#signWithOauth} before using it
  thumbnailXhr: (path, options) ->
    params = {}
    if options
      if options.format
        params.format = options.format
      else if options.png
        params.format = 'png'
      if options.size
        # Can we do something nicer here?
        params.size = options.size

    xhr = new Dropbox.Util.Xhr 'GET',
                               "#{@_urls.thumbnails}/#{@_urlEncodePath(path)}"
    xhr.setParams params

  # Reverts a file's contents to a previous version.
  #
  # This is an atomic, bandwidth-optimized equivalent of reading the file
  # contents at the given file version (readFile), and then using it to
  # overwrite the file (writeFile).
  #
  # @param {String} path the path to the file whose contents will be reverted
  #   to a previous version, relative to the user's Dropbox or to the
  #   application's folder
  # @param {String} versionTag the tag of the version that the file will be
  #   reverted to; maps to the "rev" parameter in the HTTP API
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat)} callback called with
  #   the result of the /restore HTTP request; if the call succeeds, the second
  #   parameter is a {Dropbox.File.Stat} instance describing the file after the
  #   revert operation, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  revertFile: (path, versionTag, callback) ->
    xhr = new Dropbox.Util.Xhr 'POST',
                               "#{@_urls.restore}/#{@_urlEncodePath(path)}"
    xhr.setParams(rev: versionTag).signWithOauth @_oauth
    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # Alias for "revertFile" that matches the HTTP API.
  #
  # @see Dropbox.Client#revertFile
  restore: (path, versionTag, callback) ->
    @revertFile path, versionTag, callback

  # Finds files / folders whose name match a pattern, in the user's Dropbox.
  #
  # @param {String} path the path that will serve as the root of the search,
  #   relative to the user's Dropbox or to the application's folder
  # @param {String} namePattern the string that file / folder names must
  #   contain in order to match the search criteria
  # @param {Object} options (optional) one or more of the options below
  # @option options {Number} limit if specified, the call will return at most
  #   this many versions
  # @option options {Boolean} removed if set to true, the results will include
  #   files and folders that were deleted from the user's Dropbox; the default
  #   limit is the maximum value of 1,000
  # @option options {Boolean} deleted alias for "removed" that matches the HTTP
  #   API; using this alias is not recommended, because it may cause confusion
  #   with JavaScript's delete operation
  # @option options {Boolean} httpCache if true, the API request will be set to
  #   allow HTTP caching to work; by default, requests are set up to avoid
  #   CORS preflights; setting this option can make sense when making the same
  #   request repeatedly
  # @param {function(Dropbox.ApiError, Array<Dropbox.File.Stat>)} callback
  #   called with the result of the /search HTTP request; if the call succeeds,
  #   the second parameter is an array with one {Dropbox.File.Stat} instance
  #   per search result, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  findByName: (path, namePattern, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    params = { query: namePattern }
    httpCache = false
    if options
      if options.limit?
        params.file_limit = options.limit
      if options.removed or options.deleted
        params.include_deleted = true
      if options.httpCache
        httpCache = true

    xhr = new Dropbox.Util.Xhr 'GET',
                               "#{@_urls.search}/#{@_urlEncodePath(path)}"
    xhr.setParams(params).signWithOauth @_oauth, httpCache
    @_dispatchXhr xhr, (error, results) ->
      if results
        stats = (Dropbox.File.Stat.parse(metadata) for metadata in results)
      else
        stats = undefined
      callback error, stats

  # Alias for "findByName" that matches the HTTP API.
  #
  # @see Dropbox.Client#findByName
  search: (path, namePattern, options, callback) ->
    @findByName path, namePattern, options, callback

  # Creates a reference used to copy a file to another user's Dropbox.
  #
  # @param {String} path the path to the file whose contents will be
  #   referenced, relative to the uesr's Dropbox or to the application's
  #   folder
  # @param {function(Dropbox.ApiError, Dropbox.File.CopyReference)} callback
  #   called with the result of the /copy_ref HTTP request; if the call
  #   succeeds, the second parameter is a {Dropbox.File.CopyReference}
  #   instance, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  makeCopyReference: (path, callback) ->
    xhr = new Dropbox.Util.Xhr 'GET',
                               "#{@_urls.copyRef}/#{@_urlEncodePath(path)}"
    xhr.signWithOauth @_oauth
    @_dispatchXhr xhr, (error, refData) ->
      callback error, Dropbox.File.CopyReference.parse(refData)

  # Alias for "makeCopyReference" that matches the HTTP API.
  #
  # @see Dropbox.Client#makeCopyReference
  copyRef: (path, callback) ->
    @makeCopyReference path, callback

  # Fetches a list of changes in the user's Dropbox since the last call.
  #
  # This method is intended to make full sync implementations easier and more
  # performant. Each call returns a cursor that can be used in a future call
  # to obtain all the changes that happened in the user's Dropbox (or
  # application directory) between the two calls.
  #
  # @param {Dropbox.Http.PulledChanges, String} cursor (optional) the result of
  #   a previous {Dropbox.Client#pullChanges} call, or a string containing a
  #   tag representing the Dropbox state that is used as the baseline for the
  #   change list; this should either be the {Dropbox.Http.PulledChanges}
  #   obtained from a previous call to {Dropbox.Client#pullChanges}, the return
  #   value of {Dropbox.Http.PulledChanges#cursor}, or null / omitted on the
  #   first call to {Dropbox.Client#pullChanges}
  # @param {function(Dropbox.ApiError, Dropbox.Http.PulledChanges)} callback
  #   called with the result of the /delta HTTP request; if the call
  #   succeeds, the second parameter is a {Dropbox.Http.PulledChanges}
  #   describing the changes to the user's Dropbox since the pullChanges call
  #   that produced the given cursor, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  pullChanges: (cursor, callback) ->
    if (not callback) and (typeof cursor is 'function')
      callback = cursor
      cursor = null

    if cursor
      if cursor.cursorTag  # cursor is a Dropbox.Http.PulledChanges instance
        params = { cursor: cursor.cursorTag }
      else
        params = { cursor: cursor }
    else
      params = {}

    xhr = new Dropbox.Util.Xhr 'POST', @_urls.delta
    xhr.setParams(params).signWithOauth @_oauth
    @_dispatchXhr xhr, (error, deltaInfo) ->
      callback error, Dropbox.Http.PulledChanges.parse(deltaInfo)

  # Alias for "pullChanges" that matches the HTTP API.
  #
  # @see Dropbox.Client#pullChanges
  delta: (cursor, callback) ->
    @pullChanges cursor, callback

  # Checks whether changes have occurred in a user's Dropbox.
  #
  # This method can be used together with {Dropbox.Client#pullChanges} to react
  # to changes in Dropbox in a timely manner.
  #
  # @param {Dropbox.Http.PulledChanges, String} cursor the result of a previous
  #   {Dropbox.Client#pullChanges} call, or a string containing a tag
  #   representing the Dropbox state that is used as the baseline for the
  #   change list; this should either be the {Dropbox.Http.PulledChanges}
  #   obtained from a previous call to {Dropbox.Client#pullChanges} or the
  #   return value of {Dropbox.Http.PulledChanges#cursor}
  # @param {Object} options
  # @param {function(Dropbox.ApiError, Dropbox.Http.PollResult)} callback
  #   called with the result of the /longpoll_delta HTTP request; if the call
  #   succeeds, the second parameter is a {Dropbox.Http.PollResult} instance
  #   indicating whether {Dropbox.Client#pullChanges} might return new changes,
  #   and the first parameter is null
  pollForChanges: (cursor, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    if cursor.cursorTag  # cursor is a Dropbox.Http.PulledChanges
      params = { cursor: cursor.cursorTag }
    else
      params = { cursor: cursor }

    if options and 'timeout' of options
      params.timeout = options.timeout

    xhr = new Dropbox.Util.Xhr 'GET', @_urls.longpollDelta
    xhr.setParams params
    @_dispatchXhr xhr, (error, response) ->
      if typeof response is 'string'
        try
          response = JSON.parse response
        catch jsonError
          response = null
      callback error, Dropbox.Http.PollResult.parse(response)

  # Creates a folder in a user's Dropbox.
  #
  # @param {String} path the path of the folder that will be created, relative
  #   to the user's Dropbox or to the application's folder
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat)} callback called
  #   with the result of the /fileops/create_folder HTTP request; if the call
  #   succeeds, the second parameter is a {Dropbox.File.Stat} instance
  #   describing the newly created folder, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  mkdir: (path, callback) ->
    xhr = new Dropbox.Util.Xhr 'POST', @_urls.fileopsCreateFolder
    xhr.setParams(root: 'auto', path: @_normalizePath(path)).
        signWithOauth(@_oauth)
    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # Removes a file or directory from a user's Dropbox.
  #
  # @param {String} path the path of the file to be read, relative to the
  #   user's Dropbox or to the application's folder
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat)} callback called
  #   with the result of the /fileops/delete HTTP request; if the call
  #   succeeds, the second parameter is a {Dropbox.File.Stat} instance
  #   describing the removed file or folder, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  remove: (path, callback) ->
    xhr = new Dropbox.Util.Xhr 'POST', @_urls.fileopsDelete
    xhr.setParams(root: 'auto', path: @_normalizePath(path)).
        signWithOauth(@_oauth)
    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # node.js-friendly alias for "remove".
  #
  # @see Dropbox.Client#remove
  unlink: (path, callback) ->
    @remove path, callback

  # Alias for "remove" that matches the HTTP API.
  #
  # @see Dropbox.Client#remove
  delete: (path, callback) ->
    @remove path, callback

  # Copies a file or folder in the user's Dropbox.
  #
  # This method's "from" parameter can be either a path or a copy reference
  # obtained by a previous call to {Dropbox.Client#makeCopyReference}.
  #
  # The method treats String arguments as paths and CopyReference instances as
  # copy references. The CopyReference constructor can be used to get instances
  # out of copy reference strings, or out of their JSON representations.
  #
  # @param {String, Dropbox.File.CopyReference} from the path of the file or
  #   folder that will be copied, or a {Dropbox.File.CopyReference} instance
  #   obtained by calling {Dropbox.Client#makeCopyReference} or
  #   {Dropbox.File.CopyReference.parse}; if this is a path, it is relative to
  #   the user's Dropbox or to the application's folder
  # @param {String} toPath the path that the file or folder will have after the
  #   method call; the path is relative to the user's Dropbox or to the
  #   application folder
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat)} callback called with
  #   the result of the /fileops/copy HTTP request; if the call succeeds, the
  #   second parameter is a {Dropbox.File.Stat} instance describing the file
  #   or folder created by the copy operation, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  copy: (from, toPath, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    params = { root: 'auto', to_path: @_normalizePath(toPath) }
    if from instanceof Dropbox.File.CopyReference
      params.from_copy_ref = from.tag
    else
      params.from_path = @_normalizePath from
    # TODO: locale support would edit the params here

    xhr = new Dropbox.Util.Xhr 'POST', @_urls.fileopsCopy
    xhr.setParams(params).signWithOauth @_oauth
    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # Moves a file or folder to a different location in a user's Dropbox.
  #
  # @param {String} fromPath the path of the file or folder that will be moved,
  #   relative to the user's Dropbox or to the application's folder
  # @param {String} toPath the path that the file or folder will have after
  #   the method call; the path is relative to the user's Dropbox or to the
  #   application's folder
  # @param {function(Dropbox.ApiError, Dropbox.File.Stat)} callback called with
  #   the result of the /fileops/move HTTP request; if the call succeeds,
  #   the second parameter is a {Dropbox.File.Stat} instance describing the
  #   moved file or folder at its new location, and the first parameter is null
  # @return {XMLHttpRequest} the XHR object used for this API call
  move: (fromPath, toPath, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    xhr = new Dropbox.Util.Xhr 'POST', @_urls.fileopsMove
    xhr.setParams(
        root: 'auto', from_path: @_normalizePath(fromPath),
        to_path: @_normalizePath(toPath)).signWithOauth @_oauth
    @_dispatchXhr xhr, (error, metadata) ->
      callback error, Dropbox.File.Stat.parse(metadata) if callback

  # Fetches information about a Dropbox Platform application.
  #
  # This method retrieves the same information that is displayed on the OAuth
  # authorize page, in a machine-friendly format. It is intended to be used in
  # IDEs and debugging.
  #
  # @param {String} (optional) appKey the App key of the application whose
  #   information will be retrieved; if not given, the App key passed to this
  #   Client will be used instead
  # @param {function(Dropbox.ApiError, Dropbox.Http.AppInfo)} callback called
  #   with the result of the /app/info HTTP request; if the call succeeds, the
  #   second parameter is a {Dropbox.Http.AppInfo} instance describing the
  #   application whose key was given
  # @return {XMLHttpRequest} the XHR object used for this API call
  appInfo: (appKey, callback) ->
    if (not callback) and (typeof appKey is 'function')
      callback = appKey
      appKey = @_oauth.credentials().key

    xhr = new Dropbox.Util.Xhr 'GET', @_urls.appsInfo
    xhr.setParams app_key: appKey
    @_dispatchXhr xhr, (error, appInfo) ->
      callback error, Dropbox.Http.AppInfo.parse(appInfo, appKey)

  # Checks if a user is a developer for a Dropbox Platform application.
  #
  # This is intended to be used by IDEs to validate Dropbox App keys that their
  # users input. This method can be used to make sure that users go to
  # /developers and generate their own App keys, instead of copy-pasting keys
  # from code samples. The metod can also be used to enable debugging / logging
  # in applications.
  #
  # @param {String, Dropbox.AccountInfo} userId the user whose developer status
  #   will be checked
  # @param {String, Dropbox.Http.AppInfo} appKey (optional) the API key of the
  #   application whose developer list will be checked
  # @param {function(Dropbox.ApiError, Boolean)} callback called with the
  #   result of the /app/check_developer HTTP request; if the call succeeds,
  #   the second argument will be true if the user with the given ID is a
  #   developer of the given application, and false otherwise
  # @return {XMLHttpRequest} the XHR object used for this API call
  isAppDeveloper: (userId, appKey, callback) ->
    if (typeof userId is 'object') and ('uid' of userId)
      # userId is a Dropbox.AccountInfo instance
      userId = userId.uid

    if (not callback) and (typeof appKey is 'function')
      callback = appKey
      appKey = @_oauth.credentials().key
    else if (typeof appKey is 'object') and ('key' of appKey)
      # appKey is a Dropbox.Http.AppInfo instance
      appKey = appKey.key

    xhr = new Dropbox.Util.Xhr 'GET', @_urls.appsCheckDeveloper
    xhr.setParams app_key: appKey, uid: userId
    @_dispatchXhr xhr, (error, response) ->
      if response
        callback error, response.is_developer
      else
        callback error

  # Checks if a given URI is an OAuth redirect URI for a Dropbox application.
  #
  # This is intended to be used in IDEs and debugging. The same information can
  # be obtained by checking the HTTP status in an /oauth2/authorize HTTP GET
  # with request_uri set to the desired URI.
  #
  # @param {String} redirectUri the URI that will be checked against the app's
  #   list of allowed OAuth redirect URIs
  # @param {String, Dropbox.Http.AppInfo} appKey (optional) the API key of the
  #   application whose list of allowed OAuth redirect URIs will be checked
  # @param {function(Dropbox.ApiError, Boolean)} callback called with the
  #   result of the /app/check_redirect_uri HTTP request; if the call succeeds,
  #   the second argument will be true if the given URI is on the application's
  #   list of allowed OAuth redirect URIs, and false otherwise
  # @return {XMLHttpRequest} the XHR object used for this API call
  hasOauthRedirectUri: (redirectUri, appKey, callback) ->
    if (not callback) and (typeof appKey is 'function')
      callback = appKey
      appKey = @_oauth.credentials().key
    else if (typeof appKey is 'object') and ('key' of appKey)
      # appKey is a Dropbox.Http.AppInfo instance
      appKey = appKey.key

    xhr = new Dropbox.Util.Xhr 'GET', @_urls.appsCheckRedirectUri
    xhr.setParams app_key: appKey, redirect_uri: redirectUri
    @_dispatchXhr xhr, (error, response) ->
      if response
        callback error, response.has_redirect_uri
      else
        callback error

  # Forgets all the user's information.
  #
  # {Dropbox.Client#signOut} should be called when the user expresses an intent
  # to sign off the application. This method resets user-related fields from
  # the Client instance, but does not work with the OAuth driver to do a full
  # sign out. For example, the user's OAuth 2 access token might remain in
  # localStorage.
  #
  # @return {Dropbox.Client} this, for easy call chaining
  # @see Dropbox.Client#signOut
  reset: ->
    @_uid = null
    @_oauth.reset()
    oldAuthStep = @authStep
    @authStep = @_oauth.step()
    if oldAuthStep isnt @authStep
      @onAuthStepChange.dispatch @
    @authError = null
    @_credentials = null
    @

  # Change the client's OAuth credentials.
  #
  # @param {Object} credentials the result of a prior call to
  #   {Dropbox.Client#credentials}
  # @return {Dropbox.Client} this, for easy call chaining
  setCredentials: (credentials) ->
    oldAuthStep = @authStep
    @_oauth.setCredentials credentials
    @authStep = @_oauth.step()
    @_uid = credentials.uid or null
    @authError = null
    @_credentials = null
    if oldAuthStep isnt @authStep
      @onAuthStepChange.dispatch @
    @

  # Unique identifier for the Dropbox application behind this client.
  #
  # This method is intended to be used by OAuth drivers.
  #
  # @return {String} a string that uniquely identifies the Dropbox application
  #   of this client
  appHash: ->
    @_oauth.appHash()

  # Computes the URLs of all the Dropbox API calls.
  #
  # @private
  # This is called by the constructor, and used by the other methods. It should
  # not be called directly.
  setupUrls: ->
    @_apiServer = @_chooseApiServer()
    @_urls =
      # Authentication.
      authorize: "#{@_authServer}/1/oauth2/authorize"
      token: "#{@_apiServer}/1/oauth2/token"
      signOut: "#{@_apiServer}/1/unlink_access_token"

      # Accounts.
      accountInfo: "#{@_apiServer}/1/account/info"

      # Files and metadata.
      getFile: "#{@_fileServer}/1/files/auto"
      postFile: "#{@_fileServer}/1/files/auto"
      putFile: "#{@_fileServer}/1/files_put/auto"
      metadata: "#{@_apiServer}/1/metadata/auto"
      delta: "#{@_apiServer}/1/delta"
      longpollDelta: "#{@_notifyServer}/1/longpoll_delta"
      revisions: "#{@_apiServer}/1/revisions/auto"
      restore: "#{@_apiServer}/1/restore/auto"
      search: "#{@_apiServer}/1/search/auto"
      shares: "#{@_apiServer}/1/shares/auto"
      media: "#{@_apiServer}/1/media/auto"
      copyRef: "#{@_apiServer}/1/copy_ref/auto"
      thumbnails: "#{@_fileServer}/1/thumbnails/auto"
      chunkedUpload: "#{@_fileServer}/1/chunked_upload"
      commitChunkedUpload:
          "#{@_fileServer}/1/commit_chunked_upload/auto"

      # File operations.
      fileopsCopy: "#{@_apiServer}/1/fileops/copy"
      fileopsCreateFolder: "#{@_apiServer}/1/fileops/create_folder"
      fileopsDelete: "#{@_apiServer}/1/fileops/delete"
      fileopsMove: "#{@_apiServer}/1/fileops/move"

      # Platform application information.
      appsInfo: "#{@_apiServer}/1/apps/info"
      appsCheckDeveloper: "#{@_apiServer}/1/apps/check_developer"
      appsCheckRedirectUri: "#{@_apiServer}/1/apps/check_redirect_uri"


  # Chooses an API server that will be used by this client.
  #
  # @private
  # This should only be called by {Dropbox.Client#setupUrls}.
  #
  # @return {String} the URL to the API server.
  _chooseApiServer: ->
    serverNumber = Math.floor(Math.random() * (@_maxApiServer + 1))
    serverId = if serverNumber is 0 then '' else serverNumber.toString()
    @_serverRoot.replace '$', serverId

  # @property {Number} the client's progress in the authentication process
  #
  # This property is intended to be used by OAuth drivers.
  # {Dropbox.Client#isAuthenticated} is a better method of checking whether a
  # client can be used to perform API calls.
  #
  # @see Dropbox.Client#isAuthenticated
  authStep: null

  # authStep value for a client that experienced an authentication error.
  @ERROR: 0

  # authStep value for a properly initialized client with no user credentials.
  @RESET: 1

  # authStep value for a client that has an /authorize state parameter value.
  #
  # This state is entered when the state parameter is set directly by
  # {Dropbox.Client#authenticate}. Auth drivers that need to save the OAuth
  # state parameter value during {Dropbox.AuthDriver#doAuthorize} should do so
  # when the client is in this state.
  @PARAM_SET: 2

  # authStep value for a client that has an /authorize state parameter value.
  #
  # This state is entered when the state parameter is loaded from an external
  # data source, by {Dropbox.Client#setCredentials} or
  # {Dropbox.Client#constructor}. Auth drivers that need to save the OAuth
  # state during {Dropbox.AuthDriver#doAuthorize} should check for
  # authorization completion in this state.
  @PARAM_LOADED: 3

  # authStep value for a client that has an authorization code.
  @AUTHORIZED: 4

  # authStep value for a client that has an access token.
  @DONE: 5

  # authStep value for a client that voluntarily invalidated its access token.
  @SIGNED_OUT: 6

  # Normalizes a Dropobx path and encodes it for inclusion in a request URL.
  #
  # @private
  # This is called internally by the other client functions, and should not be
  # used outside the {Dropbox.Client} class.
  _urlEncodePath: (path) ->
    Dropbox.Util.Xhr.urlEncodeValue(@_normalizePath(path)).replace /%2F/gi, '/'

  # Normalizes a Dropbox path for API requests.
  #
  # @private
  # This is an internal method. It is used by all the client methods that take
  # paths as arguments.
  #
  # @param {String} path a path
  _normalizePath: (path) ->
    if path.substring(0, 1) is '/'
      i = 1
      while path.substring(i, i + 1) is '/'
        i += 1
      path.substring i
    else
      path

  # The URL for /oauth2/authorize, embedding the user's token.
  #
  # @private
  # This should only be used by {Dropbox.Client#authenticate}.
  #
  # @return {String} the URL that the user's browser should be redirected to in
  #   order to perform an /oauth2/authorize request
  authorizeUrl: () ->
    params = @_oauth.authorizeUrlParams @_driver.authType(), @_driver.url()
    @_urls.authorize + "?" + Dropbox.Util.Xhr.urlEncode(params)

  # Exchanges an OAuth 2 authorization code with an access token.
  #
  # @private
  # This should only be used by {Dropbox.Client#authenticate}.
  #
  # @param {function(?Dropbox.ApiError|Dropbox.AuthError, Object)} callback
  #   called with the result of the /oauth/access_token HTTP request
  # @return {XMLHttpRequest} the XHR object used for this API call
  getAccessToken: (callback) ->
    params = @_oauth.accessTokenParams @_driver.url()
    xhr = new Dropbox.Util.Xhr('POST', @_urls.token).setParams(params).
        addOauthParams(@_oauth)
    @_dispatchXhr xhr, (error, data) ->
      if error and error.status is Dropbox.ApiError.INVALID_PARAM and
          error.response and error.response.error
        # Return AuthError instances for OAuth errors.
        error = new Dropbox.AuthError error.response
      callback error, data

  # Prepares and sends an XHR to the Dropbox API server.
  #
  # @private
  # This is a low-level method called by other client methods.
  #
  # @param {Dropbox.Util.Xhr} xhr wrapper for the XHR to be sent
  # @param {function(Dropbox.ApiError, Object)} callback called with the
  #   outcome of the XHR
  # @return {XMLHttpRequest} the native XHR object used to make the request
  _dispatchXhr: (xhr, callback) ->
    xhr.setCallback callback
    xhr.onError = @_xhrOnErrorHandler
    xhr.prepare()
    nativeXhr = xhr.xhr
    if @onXhr.dispatch xhr
      xhr.send()
    nativeXhr

  # Called when an XHR issued by this client fails.
  #
  # @private
  # This is a low-level method set as the onError handler for
  # {Dropbox.Util.Xhr} instances set up by this client.
  #
  # @param {Dropbox.ApiError} error the XHR error
  # @param {function()} callback called when this error handler is done
  # @return {void}
  _handleXhrError: (error, callback) ->
    if error.status is Dropbox.ApiError.INVALID_TOKEN and
        @authStep is DbxClient.DONE
      # The user's token became invalid.
      @authError = error
      @authStep = DbxClient.ERROR
      @onAuthStepChange.dispatch @
      if @_driver and @_driver.onAuthStepChange
        @_driver.onAuthStepChange @, =>
          @onError.dispatch error
          callback error
        return null
    @onError.dispatch error
    callback error
    return

  # @private
  # @return {String} the default value for the "server" option
  _defaultServerRoot: ->
    'https://api$.dropbox.com'

  # @private
  # @return {String} the default value for the "authServer" option
  _defaultAuthServer: ->
    @_serverRoot.replace 'api$', 'www'

  # @private
  # @return {String} the default value for the "fileServer" option
  _defaultFileServer: ->
    @_serverRoot.replace 'api$', 'api-content'

  # @private
  # @return {String} to the default value for the "downloadServer" option
  _defaultDownloadServer: ->
    'https://dl.dropboxusercontent.com'

  # @private
  # @return {String} to the default value for the "notifyServer" option
  _defaultNotifyServer: ->
    @_serverRoot.replace 'api$', 'api-notify'

  # @private
  # @return {Number} the default value for the "maxApiServer" option
  _defaultMaxApiServer: ->
    30

  # Computes the cached value returned by credentials.
  #
  # @private
  # Use {Dropbox.Client#credentials} instead.
  #
  # @return {void}
  _computeCredentials: ->
    value = @_oauth.credentials()
    value.uid = @_uid if @_uid
    if @_serverRoot isnt @_defaultServerRoot()
      value.server = @_serverRoot
    if @_maxApiServer isnt @_defaultMaxApiServer()
      value.maxApiServer = @_maxApiServer
    if @_authServer isnt @_defaultAuthServer()
      value.authServer = @_authServer
    if @_fileServer isnt @_defaultFileServer()
      value.fileServer = @_fileServer
    if @_downloadServer isnt @_defaultDownloadServer()
      value.downloadServer = @_downloadServer
    if @_notifyServer isnt @_defaultNotifyServer()
      value.notifyServer = @_notifyServer

    @_credentials = value
    return

DbxClient = Dropbox.Client
