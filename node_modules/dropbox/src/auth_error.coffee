# Information about an OAuth 2.0 error returned from the Dropbox API.
#
# @see http://tools.ietf.org/html/rfc6749 RFC 6749
class Dropbox.AuthError
  # @property {String} one of the {Dropbox.AuthError} constants
  code: null

  # @property {String} developer-friendly explanation of the error; can be null
  #   if the API server does not provide an explanation
  description: null

  # @property {String} URL to a developer-friendly page; can be null if the API
  #   server does not provide an URL
  uri: null

  # Error code indicating the user did not authorize the application.
  #
  # This error is reported when a user clicks the _Deny_ button on the OAuth
  # authorization page on the Dropbox site.
  @ACCESS_DENIED: 'access_denied'

  # Error code indicating a malformed OAuth request.
  #
  # This indicates a bug in dropbx.js and should never occur under normal
  # circumstanes.
  @INVALID_REQUEST: 'invalid_request'

  # Error code indicating that the client is not allowed to use a OAuth method.
  #
  # This is most likely due to an error in the application's configuration.
  # @see https://www.dropbox.com/developers/apps
  @UNAUTHORIZED_CLIENT: 'unauthorized_client'

  # Error code indicating an invalid or already-used authorization code.
  #
  # This indicates a bug in dropbox.js and should never occur under normal
  # circumstances. A faulty OAuth driver might cause this error.
  @INVALID_GRANT: 'invalid_grant'

  # Error code indicating an invalid scope parameter.
  #
  # This version of dropbox.js does not use OAuth 2.0 scopes, so this error
  # indicates a bug in the library, or that the library must be updated.
  @INVALID_SCOPE: 'invalid_scope'

  # Error code indicating an un-implemented or invalid authorization method.
  #
  # This indicates a bug in dropbox.js and should never occur under normal
  # circumstances.
  @UNSUPPORTED_GRANT_TYPE: 'unsupported_grant_type'

  # Error code indicating an un-implemented or invalid authorization method.
  #
  # This indicates a bug in dropbox.js and should never occur under normal
  # circumstances.
  @UNSUPPORTED_RESPONSE_TYPE: 'unsupported_response_type'

  # The OAuth 2.0 equivalent of a HTTP 500 error code.
  #
  # This indicates a bug in the Dropbox API server. The application and/or
  # dropbox.js will have to be modified to work around the bug.
  @SERVER_ERROR: 'server_error'

  # The OAuth 2.0 equivalent of a HTTP 503 error code.
  #
  # This occurrs when the application is rate-limited.
  @TEMPORARILY_UNAVAILABLE: 'temporarily_unavailable'

  # Wraps an XHR error.
  #
  # @param {Object} queryString a parsed response from the /authorize or /token
  #   OAuth 2.0 endpoints
  # @throw {Error} if queryString does not represent an OAuth 2.0 error
  #   response
  constructor: (queryString) ->
    unless queryString.error
      throw new Error("Not an OAuth 2.0 error: #{JSON.stringify(queryString)}")

    if typeof queryString.error is 'object' and queryString.error.error
      # The API server sometimes returns the OAuth 2.0 error information
      # wrapped in an 'error' object.
      root = queryString.error
    else
      root = queryString
    @code = root.error
    @description = root.error_description or null
    @uri = root.error_uri or null

  # Developer-friendly summary of the error.
  #
  # @private
  # @return {String} developer-friendly summary of the error
  toString: ->
    "Dropbox OAuth error #{@code} :: #{@description}"

  # Used by some testing frameworks.
  #
  # @private
  # @return {String} used by some testing frameworks
  inspect: ->
    @toString()
