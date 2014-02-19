# OAuth driver code common to Chrome apps and extensions.
#
# @private
# Application code should use {Dropbox.AuthDriver.ChromeApp} or
# {Dropbox.AuthDriver.ChromeExtension}.
class Dropbox.AuthDriver.ChromeBase extends Dropbox.AuthDriver.BrowserBase
  # Sets up an OAuth driver for Chrome.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} scope embedded in the chrome.storage.local key
  #   that holds the authentication data; useful for having multiple OAuth
  #   tokens in a single application
  constructor: (options) ->
    super options
    @storageKey = "dropbox_js_#{@scope}_credentials"

  # Saves token information when appropriate.
  onAuthStepChange: (client, callback) ->
    switch client.authStep
      when Dropbox.Client.RESET
        @loadCredentials (credentials) ->
          client.setCredentials credentials if credentials
          callback()
      when Dropbox.Client.DONE
        @storeCredentials client.credentials(), callback
      when Dropbox.Client.SIGNED_OUT
        @forgetCredentials callback
      when Dropbox.Client.ERROR
        @forgetCredentials callback
      else
        callback()

  # URL of the redirect receiver page that messages the app / extension.
  #
  # @see Dropbox.AuthDriver#url
  url: ->
    @receiverUrl

  # Stores a Dropbox.Client's credentials in local storage.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {Object} credentials the result of a Drobpox.Client#credentials call
  # @param {function()} callback called when the storing operation is complete
  # @return {Dropbox.AuthDriver.BrowserBase} this, for easy call chaining
  storeCredentials: (credentials, callback) ->
    items= {}
    items[@storageKey] = credentials
    chrome.storage.local.set items, callback
    @

  # Retrieves a token and secret from localStorage.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {function(?Object)} callback supplied with the credentials object
  #   stored by a previous call to
  #   Dropbox.AuthDriver.BrowserBase#storeCredentials; null if no credentials
  #   were stored, or if the previously stored credentials were deleted
  # @return {Dropbox.AuthDriver.BrowserBase} this, for easy call chaining
  loadCredentials: (callback) ->
    chrome.storage.local.get @storageKey, (items) =>
      callback items[@storageKey] or null
    @

  # Deletes information previously stored by a call to storeCredentials.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {function()} callback called after the credentials are deleted
  # @return {Dropbox.AuthDriver.BrowserBase} this, for easy call chaining
  forgetCredentials: (callback) ->
    chrome.storage.local.remove @storageKey, callback
    @

# OAuth driver code specific to Chrome packaged applications.
#
# @see http://developer.chrome.com/apps/about_apps.html
class Dropbox.AuthDriver.ChromeApp extends Dropbox.AuthDriver.ChromeBase
  # Sets up an OAuth driver for a Chrome packaged application.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} scope embedded in the chrome.storage.local key
  #   that holds the authentication data; useful for having multiple OAuth
  #   tokens in a single application
  constructor: (options) ->
    super options
    @receiverUrl = "https://#{chrome.runtime.id}.chromiumapp.org/"

  # Uses the Chrome identity API to drive the OAut 2 flow.
  #
  # @see Dropbox.AuthDriver#doAuthorize
  # @see http://developer.chrome.com/apps/identity.html
  doAuthorize: (authUrl, stateParam, client, callback) ->
    chrome.identity.launchWebAuthFlow url: authUrl, interactive: true,
        (redirectUrl) =>
          if @locationStateParam(redirectUrl) is stateParam
            stateParam = false  # Avoid having this matched in the future.
            callback Dropbox.Util.Oauth.queryParamsFromUrl(redirectUrl)


# OAuth driver code specific to Chrome extensions.
class Dropbox.AuthDriver.ChromeExtension extends Dropbox.AuthDriver.ChromeBase
  # Sets up an OAuth driver for a Chrome extension.
  #
  # @param {Object} options (optional) one or more of the options below
  # @option options {String} scope embedded in the chrome.storage.local key
  #   that holds the authentication data; useful for having multiple OAuth
  #   tokens in a single application
  # @option options {String} receiverPath the path of page that receives the
  #   /authorize redirect and calls {Dropbox.AuthDriver.Chrome.oauthReceiver};
  #   the path should be relative to the extension folder; by default, is
  #   'chrome_oauth_receiver.html'
  constructor: (options) ->
    super options
    receiverPath = (options and options.receiverPath) or
        'chrome_oauth_receiver.html'
    @receiverUrl = chrome.runtime.getURL receiverPath

  # Shows the authorization URL in a new tab, waits for it to send a message.
  #
  # @see Dropbox.AuthDriver#doAuthorize
  doAuthorize: (authUrl, stateParam, client, callback) ->
    oauthTab = null
    listener = (message, sender) =>
      # Reject messages not coming from the OAuth receiver window.
      if sender and sender.tab
        unless sender.tab.url.substring(0, @receiverUrl.length) is @receiverUrl
          return

      # Reject improperly formatted messages.
      return unless message.dropbox_oauth_receiver_href

      receiverHref = message.dropbox_oauth_receiver_href
      if @locationStateParam(receiverHref) is stateParam
        stateParam = false  # Avoid having this matched in the future.
        chrome.tabs.remove oauthTab.id if oauthTab
        chrome.runtime.onMessage.removeListener listener
        callback Dropbox.Util.Oauth.queryParamsFromUrl(receiverHref)
    chrome.runtime.onMessage.addListener listener

    chrome.tabs.create url: authUrl, active: true, pinned: false, (tab) ->
      oauthTab = tab

  # Communicates with the driver from the OAuth receiver page.
  #
  # The easiest way for a Chrome extension to keep up to date with dropbox.js
  # is to set up a popup receiver page that loads dropbox.js and calls this
  # method. This guarantees that the code used to communicate between the popup
  # receiver page and {Dropbox.AuthDriver.ChromeExtension#doAuthorize} stays up
  # to date as dropbox.js is updated.
  @oauthReceiver: ->
    window.addEventListener 'load', ->
      pageUrl = window.location.href
      window.location.hash = ''  # Remove the token from the browser history.
      chrome.runtime.sendMessage dropbox_oauth_receiver_href: pageUrl
      window.close() if window.close
