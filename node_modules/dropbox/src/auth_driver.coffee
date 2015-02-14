# The interface implemented by dropbox.js OAuth drivers.
#
# This class exists solely for the purpose of documenting the OAuth driver
# interface. It should not be instantiated or inherited from.
class Dropbox.AuthDriver
  # The authorization grant type used by this driver.
  #
  # Currently, server application drivers should return "code" to use
  # Authorization Code Grant (RFC 6749 Section 4.1) and drivers that run in
  # browsers or mobile clients should return "token" to use Implicit Grant (RFC
  # 6749 Section 4.2).
  #
  # @return {String} one of the OAuth 2.0 authorization grant types implemented
  #   by dropbox.js
  #
  # @see http://tools.ietf.org/html/rfc6749#section-4.1 RFC 6749 Section 4.1
  # @see http://tools.ietf.org/html/rfc6749#section-4.2 RFC 6749 Section 4.2
  authType: ->
    "code"

  # The redirect URL that should be supplied to the OAuth 2 /authorize call.
  #
  # The driver must be able to intercept redirects to the returned URL and
  # extract the OAuth 2.0 authorization code or access token from the URL.
  #
  # OAuth 2.0 redirect URLs must be configured on the application's page in
  # the {https://www.dropbox.com/developers/apps Dropbox App console}.
  #
  # @return {String} an URL on the application's list of OAuth 2 redirect URLs
  url: ->
    "https://some.url"

  # Redirects users to /authorize and waits for them to get redirected back.
  #
  # This method is called when the OAuth 2 process reaches the
  # {Dropbox.Client.PARAM_SET} step, meaning that the user must be shown an
  # /authorize page on the Dropbox servers, and the application must intercept
  # a redirect from that page. The redirect URL contains an OAuth 2
  # authorization code or access token.
  #
  # @param {String} authUrl the URL that users should be sent to in order to
  #   authorize the application's token; this points to a webpage on
  #   Dropbox's server
  # @param {String} stateParam the nonce sent as the OAuth 2 state parameter;
  #   the Dropbox Web server will echo this nonce in the 'state' query
  #   parameter when redirecting users to the URL returned by
  #   {Dropbox.AuthDriver#url}; the driver should silently ignore any request
  #   that does not contain the correct 'state' parameter value
  # @param {Dropbox.Client} client the client driving the OAuth 2 process
  # @param {function(Object<String, String>)} callback called when users have
  #   completed the authorization flow; the driver should call this when
  #   Dropbox redirects users to the URL returned by the url() method, and the
  #   "state" query parameter matches the value passed in "state"; the callback
  #   should receive the query parameters in the redirect URL
  #
  # @see Dropbox.Util.Oauth.queryParamsFromUrl
  doAuthorize: (authUrl, stateParam, client, callback) ->
    callback code: 'access-code'

  # (optional) Called to obtain the state param used in the OAuth 2 process.
  #
  # If a driver does not define this method,
  # {Dropbox.Util.Oauth.randomAuthStateParam} is used to generate a random
  # state param value.
  #
  # Server-side drivers should provide custom implementations that use a
  # derivative of the CSRF token associated with the user's session cookie.
  # This prevents CSRF attacks that would trick the application's server into
  # using an attacker's OAuth 2 access token to store anoher user's data in the
  # attacker's Dropbox.
  #
  # Client-side drivers only need to supply a custom implementation if the
  # state parameter must be persisted across page reloads, e.g. if the
  # authorization is done via redirects.
  #
  # @param {Dropbox.Client} client the client driving the OAuth 2 process
  # @param {function(String)} callback called with the state parameter value
  #   that should be used in the OAuth 2 authorization process
  getStateParam: (client, callback) ->
    callback Dropbox.Util.Oauth.randomAuthStateParam()

  # (optional) Called to process the /authorize redirect.
  #
  # This method is called when the OAuth 2 process reaches the
  # {Dropbox.Client.PARAM_LOADED} step, meaning that an OAuth 2 state parameter
  # value was loaded when the Dropbox.Client object was constructed, or during
  # a {Dropbox.Client#setCredentials} call. This means that
  # {Dropbox.AuthDriver#doAuthorize} was called earlier, saved that state
  # parameter, and did not complete the OAuth 2 process. This happens when the
  # OAuth 2 process requires page reloads, e.g. if the authorization is done
  # via redirects.
  #
  # @param {String} stateParam the nonce sent as the OAuth 2 state parameter;
  #   the Dropbox Web server will echo this nonce in the 'state' query
  #   parameter when redirecting users to the URL returned by
  #   {Dropbox.AuthDriver#url}; the driver should silently ignore any request
  #   that does not contain the correct 'state' parameter value
  # @param {Dropbox.Client} client the client driving the OAuth 2 process
  # @param {function(Object<String, String>)} callback called when the user has
  #   completed the authorization flow; the driver should call this when
  #   Dropbox redirects the user to the URL returned by
  #   {Dropbox.AuthDriver#url}, and the "state" query parameter matches the
  #   value passed in "state"; the callback should receive the query parameters
  #   in the redirect URL
  resumeAuthorize: (stateParam, client, callback) ->
    callback code: 'access-code'

  # If defined, called when there is some progress in the OAuth 2 process.
  #
  # The OAuth 2 process goes through the following states:
  #
  # * Dropbox.Client.RESET - the client has no OAuth 2 credentials, and is
  #   about to generate an OAuth 2 state nonce
  # * Dropbox.Client.PARAM_SET - the client (or driver) has generated an OAuth
  #   2 state nonce, and is about to attempt to obtain an access token or
  #   authorization code
  # * Dropbox.Client.PARAM_LOADED - the client (or driver) has loaded a
  #   previously generated OAuth 2 state nonce, and is about to resume the
  #   process of obtaining an access token or authorization code; this step is
  #   only used when the OAuth 2 process requires page reloads, e.g. in a
  #   redirect-based process
  # * Dropbox.Client.AUTHORIZED - the client has an authorization code, and is
  #   about to exchange it for an access token
  # * Dropbox.Client.DONE - the client has an OAuth 2 access token that can be
  #   used for all API calls; the OAuth 2 process is complete, and the callback
  #   passed to authorize is about to be called
  # * Dropbox.Client.SIGNED_OUT - the client's Dropbox.Client#signOut() was
  #   called, and the client's OAuth 2 access token was invalidated
  # * Dropbox.Client.ERROR - the client encounered an error during the OAuth 2
  #   process; the callback passed to authorize is about to be called with the
  #   error information
  #
  # @param {Dropbox.Client} client the client performing the OAuth process
  # @param {function()} callback called when onAuthStateChange acknowledges the
  #   state change
  onAuthStepChange: (client, callback) ->
    callback()

  # Query parameters that should be processed by doAuthorize.
  @oauthQueryParams: [
    # RFC 6749: 4.2.2. Access Token Response (Implicit Grant)
    'access_token', 'expires_in', 'scope', 'token_type',

    # RFC 6749: 4.1.2. Authorization Response (Authorization Code)
    'code',

    # RFC 6749: 4.1.2.1. and 4.2.2.1. Error Response (everything)
    'error', 'error_description', 'error_uri',

    # draft-ietf-oauth-v2-http-mac-03: 4.1. Session Key Transport to Client
    # (Implicit Grant, MAC tokens)
    'mac_key', 'mac_algorithm'
  ].sort()
