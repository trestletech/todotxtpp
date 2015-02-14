# Information about a failed call to the Dropbox API.
class Dropbox.ApiError
  # @property {Number} the HTTP error code (e.g., 403)
  #
  # This number should be compared against the constants defined on
  # {Dropbox.ApiError}.
  status: null

  # @property {String} the HTTP method of the failed request (e.g., 'GET')
  method: null

  # @property {String} the URL of the failed request
  url: null

  # @property {String} the body of the HTTP error response; can be null if
  #   the error was caused by a network failure or by a security issue
  responseText: null

  # @property {Object} the result of parsing the JSON in the HTTP error
  #   response; can be null if the API server didn't return JSON, or if the
  #   HTTP response body is unavailable
  response: null

  # Status value indicating an error at the XMLHttpRequest layer.
  #
  # This indicates a network transmission error on modern browsers. Internet
  # Explorer might cause this code to be reported on some API server errors.
  @NETWORK_ERROR: 0

  # Status value indicating that the API call will not receive a response.
  #
  # This happens when the contentHash parameter passed to a
  # {Dropbox.Client#readdir} or {Dropbox.Client#stat} matches the most recent
  # content, so the API call response is omitted, to save bandwidth.
  @NO_CONTENT: 304

  # Status value indicating an invalid input parameter.
  #
  # The error property on {Dropbox.ApiError#response} should indicate which
  # input parameter is invalid and why.
  @INVALID_PARAM: 400

  # Status value indicating an expired or invalid OAuth token.
  #
  # The OAuth token used for the request will never become valid again, so the
  # user should be re-authenticated.
  #
  # The {Dropbox.Client#authStep} property of the client used to make the API
  # call will automatically transition from {Dropbox.Client.DONE} to
  # {Dropbox.Client.ERROR} when this error is received.
  @INVALID_TOKEN: 401

  # Status value indicating a malformed OAuth request.
  #
  # This indicates a bug in dropbox.js and should never occur under normal
  # circumstances.
  @OAUTH_ERROR: 403

  # Status value indicating that a file or path was not found in Dropbox.
  #
  # This happens when trying to read from a non-existing file, readdir a
  # non-existing directory, write a file into a non-existing directory, etc.
  @NOT_FOUND: 404

  # Status value indicating that the HTTP method is not supported for the call.
  #
  # This indicates a bug in dropbox.js and should never occur under normal
  # circumstances.
  @INVALID_METHOD: 405

  # Status value indicating that the API call disobeys some constraints.
  #
  # This happens when a {Dropbox.Client#readdir} or {Dropbox.Client#stat} call
  # would return more than a maximum amount of directory entries.
  @NOT_ACCEPTABLE: 406

  # Status value indicating that the server received a conflicting update.
  #
  # This is used by some backend methods to indicate that the client needs to
  # download server-side changes and perform conflict resolution. Under normal
  # usage, errors with this code should never surface to the code using
  # dropbox.js.
  @CONFLICT: 409

  # Status value indicating that the application is making too many requests.
  #
  # Rate-limiting can happen on a per-application or per-user basis.
  @RATE_LIMITED: 429

  # Status value indicating a server issue.
  #
  # The request should be retried after some time.
  @SERVER_ERROR: 503

  # Status value indicating that the user's Dropbox is over its storage quota.
  #
  # The application UI should communicate to the user that their data cannot be
  # stored in Dropbox.
  @OVER_QUOTA: 507

  # Wraps a failed XHR call to the Dropbox API.
  #
  # @param {String} method the HTTP verb of the API request (e.g., 'GET')
  # @param {String} url the URL of the API request
  # @param {XMLHttpRequest} xhr the XMLHttpRequest instance of the failed
  #   request
  constructor: (xhr, @method, @url) ->
    @status = xhr.status
    if xhr.responseType
      try
        text = xhr.response or xhr.responseText
      catch xhrError
        try
          text = xhr.responseText
        catch xhrError
          text = null
    else
      try
        text = xhr.responseText
      catch xhrError
        text = null

    if text
      try
        @responseText = text.toString()
        @response = JSON.parse text
      catch xhrError
        @response = null
    else
      @responseText = '(no response)'
      @response = null

  # Developer-friendly summary of the error.
  #
  # @private
  # @return {String} developer-friendly summary of the error
  toString: ->
    "Dropbox API error #{@status} from #{@method} #{@url} :: #{@responseText}"

  # Used by some testing frameworks.
  #
  # @private
  # @return {String} used by some testing frameworks
  inspect: ->
    @toString()
