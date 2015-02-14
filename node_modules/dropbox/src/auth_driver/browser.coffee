# Base class for OAuth drivers that run in the browser.
#
# Inheriting from this class makes a driver use HTML5 localStorage to preserve
# OAuth tokens across page reloads.
class Dropbox.AuthDriver.BrowserBase
  # Sets up the OAuth driver.
  #
  # Subclasses should pass the options object they receive to the superclass
  # constructor.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  # @option options {Boolean} rememberUser if false, the user's OAuth tokens
  #   are not saved in localStorage; true by default
  constructor: (options) ->
    if options
      @rememberUser = if 'rememberUser' of options
        options.rememberUser
      else
        true
      @scope = options.scope or 'default'
    else
      @rememberUser = true
      @scope = 'default'
    @storageKey = null
    @storage = Dropbox.AuthDriver.BrowserBase.localStorage()

    @stateRe = /^[^#]+\#(.*&)?state=([^&]+)(&|$)/

  # Browser-side authentication should always use OAuth 2 Implicit Grant.
  #
  # @see Dropbox.AuthDriver#authType
  authType: ->
    'token'

  # Persists tokens.
  #
  # @see Dropbox.AuthDriver#onAuthStepChange
  onAuthStepChange: (client, callback) ->
    @setStorageKey client

    switch client.authStep
      when Dropbox.Client.RESET
        @loadCredentials (credentials) =>
          return callback() unless credentials

          client.setCredentials credentials
          if client.authStep isnt Dropbox.Client.DONE
            return callback()

          # There is an old access token. Only use it if the app supports
          # logout.
          unless @rememberUser
            return @forgetCredentials(callback)

          client.setCredentials credentials
          callback()
      when Dropbox.Client.DONE
        if @rememberUser
          return @storeCredentials(client.credentials(), callback)
        @forgetCredentials callback
      when Dropbox.Client.SIGNED_OUT
        @forgetCredentials callback
      when Dropbox.Client.ERROR
        @forgetCredentials callback
      else
        callback()
        @

  # Computes the @storageKey used by loadCredentials and forgetCredentials.
  #
  # @private
  # This is called by onAuthStepChange.
  #
  # @param {Dropbox.Client} client the client instance that is running the
  #     authorization process
  # @return {Dropbox.AuthDriver} this, for easy call chaining
  setStorageKey: (client) ->
    # NOTE: the storage key is dependent on the app hash so that multiple apps
    #       hosted off the same server don't step on eachother's toes
    @storageKey = "dropbox-auth:#{@scope}:#{client.appHash()}"
    @

  # Stores a Dropbox.Client's credentials in localStorage.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {Object} credentials the result of a Drobpox.Client#credentials call
  # @param {function()} callback called when the storing operation is complete
  # @return {Dropbox.AuthDriver.BrowserBase} this, for easy call chaining
  storeCredentials: (credentials, callback) ->
    jsonString = JSON.stringify credentials
    try
      @storage.setItem @storageKey, jsonString
    catch storageError
      # Safari disables localStorage in Private Browsing mode.
      name = encodeURIComponent @storageKey
      value = encodeURIComponent jsonString
      document.cookie = "#{name}=#{value}; path=/"

    callback()
    @

  # Retrieves a token and secret from localStorage.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {function(Object)} callback supplied with the credentials object
  #   stored by a previous call to
  #   {Dropbox.AuthDriver.BrowserBase#storeCredentials}; the argument is null
  #   if no credentials were stored, or if the previously stored credentials
  #   were deleted
  # @return {Dropbox.AuthDriver.BrowserBase} this, for easy call chaining
  loadCredentials: (callback) ->
    try
      jsonString = @storage.getItem @storageKey
    catch storageError
      # Safari disables localStorage in Private Browsing mode, but
      # localStorage.getItem exists and returns null. This is here to mimic
      # that behavior in environments that have localStorage disabled for some
      # reason.
      jsonString = null

    if jsonString is null
      # Safari disables localStorage in Private Browsing mode. We need to check
      # for cookies as well.
      name = encodeURIComponent @storageKey

      # Characters unescaped by encodeURIComponent:
      # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent
      # Characters that must be escaped in regular expressions:
      # http://stackoverflow.com/a/3561711/537046
      nameRegexp = name.replace(/[.*+()]/g, '\\$&')
      cookieRegexp = new RegExp "(^|(;\\s*))#{name}=([^;]*)(;|$)"
      if match = cookieRegexp.exec(document.cookie)
        jsonString = decodeURIComponent match[3]

    unless jsonString
      callback null
      return @

    try
      callback JSON.parse(jsonString)
    catch jsonError
      # Parse errors.
      callback null
    @

  # Deletes information previously stored by a call to storeCredentials.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {function()} callback called after the credentials are deleted
  # @return {Dropbox.AuthDriver.BrowserBase} this, for easy call chaining
  forgetCredentials: (callback) ->
    try
      @storage.removeItem @storageKey
    catch storageError
      # Safari disables localStorage in Private Browsing mode.
      name = encodeURIComponent @storageKey
      expires = (new Date(0)).toGMTString()
      document.cookie = "#{name}={}; expires=#{expires}; path=/"
    callback()
    @

  # Figures out if a URL is an OAuth 2.0 /authorize redirect URL.
  #
  # @param {String} the URL to check; if null, the current location's URL is
  #   checked
  # @return {String} the state parameter value received from the /authorize
  #   redirect, or null if the URL is not the result of an /authorize redirect
  locationStateParam: (url) ->
    location = url or Dropbox.AuthDriver.BrowserBase.currentLocation()

    # Extract the state.
    match = @stateRe.exec location
    return decodeURIComponent(match[2]) if match

    null

  # Replaces the filename (basename) in an URL.
  #
  # @private
  # This is used by subclasses to compute the redirect_uri value passed to
  # /authorize.
  #
  # @param {String} url the URL whose basename will be replaced
  # @param {String} basename the file name in the returned URL
  # @return {String} an URL whose basename has been replaced; the URL will not
  #   have a query or fragment
  replaceUrlBasename: (url, basename) ->
    hashIndex = url.indexOf '#'
    url = url.substring 0, hashIndex if hashIndex isnt -1
    queryIndex = url.indexOf '?'
    url = url.substring 0, queryIndex if queryIndex isnt -1
    fragments = url.split '/'
    fragments[fragments.length - 1] = basename
    fragments.join '/'

  # Wrapper for window.localStorage.
  #
  # Drivers should call this method instead of using localStorage directly, to
  # simplify stubbing.
  #
  # @return {Storage} the browser's implementation of the WindowLocalStorage
  #   interface in the Web Storage specification
  @localStorage: ->
    if typeof window isnt 'undefined'
      try
        window.localStorage
      catch deprecationError
        # Simply accessing window.localStorage in Chrome apps is deprecated.
        null
    else
      null

  # Wrapper for window.location.
  #
  # Drivers should call this method instead of using browser APIs directly, to
  # simplify stubbing.
  #
  # @return {String} the current page's URL
  @currentLocation: ->
    window.location.href

  # Removes the OAuth 2 access token from the current page's URL.
  #
  # This hopefully also removes the access token from the browser history.
  #
  # @return {void}
  @cleanupLocation: ->
    if window.history and window.history.replaceState
      pageUrl = @currentLocation()
      hashIndex = pageUrl.indexOf '#'
      window.history.replaceState {}, document.title,
                                  pageUrl.substring(0, hashIndex)
    else
      window.location.hash = ''
    return


# OAuth driver that uses a redirect and localStorage to complete the flow.
class Dropbox.AuthDriver.Redirect extends Dropbox.AuthDriver.BrowserBase
  # Sets up the redirect-based OAuth driver.
  #
  # @param {Object} options (optional) one more of the options below
  # @option options {String} redirectUrl URL to the page that receives the
  #   /authorize redirect
  # @option options {String} redirectFile the URL to the receiver page will be
  #   computed by replacing the file name (everything after the last /) of
  #   the current location with this parameter's value
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  # @option options {Boolean} rememberUser if false, the user's OAuth tokens
  #   are not saved in localStorage; true by default
  constructor: (options) ->
    super options
    @receiverUrl = @baseUrl options

  # The URL of the page that will receive the callback.
  #
  # @private
  # This should only be called by the constructor.
  #
  # @param {Object} options (optional) the options passed to the constructor
  # @option options {String} redirectUrl URL to the page that receives the
  #   /authorize redirect
  # @option options {String} redirectFile the URL to the receiver page will be
  #   computed by replacing the file name (everything after the last /) of
  #   the current location with this parameter's value
  # @return {String} the current URL, minus any fragment it might have
  baseUrl: (options) ->
    url = Dropbox.AuthDriver.BrowserBase.currentLocation()
    if options
      if options.redirectUrl
        return options.redirectUrl
      if options.redirectFile
        return @replaceUrlBasename(url, options.redirectFile)

    hashIndex = url.indexOf '#'
    url = url.substring 0, hashIndex if hashIndex isnt -1
    url

  # URL of the page that the user will be redirected to.
  #
  # @return {String} the URL of the app page that the user will be redirected
  #   to after /authorize; if no constructor option is set, this will be the
  #   current page
  # @see Dropbox.AuthDriver#url
  url: ->
    @receiverUrl

  # Saves the OAuth 2 credentials, and redirects to the authorize page.
  #
  # @see Dropbox.AuthDriver#doAuthorize
  doAuthorize: (authUrl, stateParam, client) ->
    @storeCredentials client.credentials(), ->
      window.location.assign authUrl

  # Finishes the OAuth 2 process after the user has been redirected.
  #
  # @see Dropbox.AuthDriver#resumeAuthorize
  resumeAuthorize: (stateParam, client, callback) ->
    if @locationStateParam() is stateParam
      pageUrl = Dropbox.AuthDriver.BrowserBase.currentLocation()
      Dropbox.AuthDriver.BrowserBase.cleanupLocation()
      callback Dropbox.Util.Oauth.queryParamsFromUrl pageUrl
    else
      @forgetCredentials ->
        callback error: 'Authorization error'


# OAuth driver that uses a popup window and postMessage to complete the flow.
class Dropbox.AuthDriver.Popup extends Dropbox.AuthDriver.BrowserBase
  # Sets up a popup-based OAuth driver.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} receiverUrl URL to the page that receives the
  #   /authorize redirect and performs the postMessage
  # @option options {String} receiverFile the URL to the receiver page will be
  #   computed by replacing the file name (everything after the last /) of
  #   the current location with this parameter's value
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  # @option options {Boolean} rememberUser if false, the user's OAuth tokens
  #   are not saved in localStorage; true by default
  constructor: (options) ->
    super options
    @receiverUrl = @baseUrl options

  # URL of the redirect receiver page, which posts a message back to this page.
  #
  # @return {String} receiver page URL
  # @see Dropbox.AuthDriver#url
  url: ->
    @receiverUrl

  # Shows the authorization URL in a pop-up, waits for it to send a message.
  #
  # @see Dropbox.AuthDriver#doAuthorize
  doAuthorize: (authUrl, stateParam, client, callback) ->
    @listenForMessage stateParam, callback
    @openWindow authUrl

  # The URL of the page that will receive the OAuth callback.
  #
  # @private
  # This should only be called by the constructor.
  #
  # @param {Object} options the options passed to the constructor
  # @option options {String} receiverUrl URL to the page that receives the
  #   /authorize redirect and performs the postMessage
  # @option options {String} receiverFile the URL to the receiver page will be
  #   computed by replacing the file name (everything after the last /) of
  #   the current location with this parameter's value
  # @return {String} absolute URL of the receiver page
  baseUrl: (options) ->
    url = Dropbox.AuthDriver.BrowserBase.currentLocation()
    if options
      if options.receiverUrl
        return options.receiverUrl
      else if options.receiverFile
        return @replaceUrlBasename(url, options.receiverFile)
    url

  # Creates a popup window.
  #
  # @private
  # This should only be called by {Dropbox.AuthDriver.Popup#doAuthorize}.
  #
  # @param {String} url the URL that will be loaded in the popup window
  # @return {DOMRef} reference to the opened window, or null if the call failed
  openWindow: (url) ->
    window.open url, '_dropboxOauthSigninWindow', @popupWindowSpec(980, 700)

  # Spec string for window.open to create a nice popup.
  #
  # @private
  # This should only be called by {Dropbox.AuthDriver.Popup#openWindow}.
  #
  # @param {Number} popupWidth the desired width of the popup window
  # @param {Number} popupHeight the desired height of the popup window
  # @return {String} spec string for the popup window
  popupWindowSpec: (popupWidth, popupHeight) ->
    # Metrics for the current browser window.
    x0 = window.screenX ? window.screenLeft
    y0 = window.screenY ? window.screenTop
    width = window.outerWidth ? document.documentElement.clientWidth
    height = window.outerHeight ? document.documentElement.clientHeight

    # Computed popup window metrics.
    popupLeft = Math.round x0 + (width - popupWidth) / 2
    popupTop = Math.round y0 + (height - popupHeight) / 2.5
    popupLeft = x0 if popupLeft < x0
    popupTop = y0 if popupTop < y0

    # The specification string.
    "width=#{popupWidth},height=#{popupHeight}," +
      "left=#{popupLeft},top=#{popupTop}" +
      'dialog=yes,dependent=yes,scrollbars=yes,location=yes'

  # Listens for a postMessage from a previously opened popup window.
  #
  # @private
  # This should only be called by {Dropbox.AuthDriver.Popup#doAuthorize}.
  #
  # @param {String} stateParam the state parameter passed to the OAuth 2
  #   /authorize endpoint
  # @param {function()} called when the received message matches stateParam
  listenForMessage: (stateParam, callback) ->
    listener = (event) =>
      if event.data
        # Message coming from postMessage.
        data = event.data
      else
        # Message coming from Dropbox.Util.EventSource.
        data = event

      try
        oauthInfo = JSON.parse(data)._dropboxjs_oauth_info
      catch jsonError
        return
      return unless oauthInfo
      if @locationStateParam(oauthInfo) is stateParam
        stateParam = false  # Avoid having this matched in the future.
        window.removeEventListener 'message', listener
        Dropbox.AuthDriver.Popup.onMessage.removeListener listener
        callback Dropbox.Util.Oauth.queryParamsFromUrl(data)
    window.addEventListener 'message', listener, false
    Dropbox.AuthDriver.Popup.onMessage.addListener listener

  # The origin of a location, in the context  of the same-origin policy.
  #
  # @param {String} location the URL whose origin is computed
  # @return {String} the location's origin
  @locationOrigin: (location) ->
    # file:// URLs -- the origin is the whole path
    match = /^(file:\/\/[^\?\#]*)(\?|\#|$)/.exec location
    return match[1] if match

    # xxx:// URLs -- the origin is the scheme and the first path segment
    # e.g. http://, https://
    match = /^([^\:]+\:\/\/[^\/\?\#]*)(\/|\?|\#|$)/.exec location
    return match[1] if match

    # e.g., data: URLs -- the origin is everything
    location

  # Communicates with the driver from the OAuth receiver page.
  #
  # The easiest way for an application to keep up to date with dropbox.js is to
  # set up a popup receiver page that loads dropbox.js and calls this method.
  # This guarantees that the code used to communicate between the popup
  # receiver page and {Dropbox.AuthDriver.Popup#doAuthorize} stays up to date
  # as dropbox.js is updated.
  #
  # @return {void}
  @oauthReceiver: ->
    window.addEventListener 'load', ->
      pageUrl = window.location.href
      message = JSON.stringify _dropboxjs_oauth_info: pageUrl
      Dropbox.AuthDriver.BrowserBase.cleanupLocation()
      opener = window.opener
      if window.parent isnt window.top
        opener or= window.parent
      if opener
        try
          pageOrigin = window.location.origin or locationOrigin(pageUrl)
          opener.postMessage message, pageOrigin
          window.close()
        catch ieError
          # IE <= 9 doesn't support opener.postMessage for popup windows.
        try
          # postMessage doesn't work in IE, but direct object access does.
          opener.Dropbox.AuthDriver.Popup.onMessage.dispatch message
          window.close()
        catch frameError
          # Got nothing left to do.
          # Leave the window opened so it can be debugged.
    return

  # Works around postMessage failures on Internet Explorer.
  #
  # @private
  # This should only be used by {Dropbox.AuthDriver.Popup#doAuthorize} and
  # {Dropbox.AuthDriver.Popup.oauthReceiver}.
  @onMessage = new Dropbox.Util.EventSource
