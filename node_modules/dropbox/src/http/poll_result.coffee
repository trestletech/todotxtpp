# Wraps a {Dropbox.Client#pollForChanges} response.
#
# @see Dropbox.Client#pollForChanges
class Dropbox.Http.PollResult
  # Creates a PollResult instance from a /longpoll_delta API call result.
  #
  # @param {Object} response the parsed JSON of a /longpoll_delta API call
  #   result
  # @return {Dropbox.Http.PollResult} a PollResult instance wrapping the given
  #   response to a poll for Dropbox changes
  @parse: (response) ->
    if response
      new Dropbox.Http.PollResult response
    else
      response

  # @property {Boolean} true if there have been changes in the user's Dropbox;
  #   {Dropbox.Client#pullChanges} can be called to obtain the changes
  hasChanges: undefined

  # @property {Number} seconds that the client must wait for before making
  #   another {Dropbox.Client#pollForChanges} call
  retryAfter: undefined

  # Creates a PollResult instance from a /longpoll_delta API call result.
  #
  # @private
  # This constructor is used by {Dropbox.Http.PollResult.parse}, and should
  # not be called directly.
  #
  # @param {Object} response the parsed JSON of a /longpoll_delta API call
  #   result
  constructor: (response) ->
    @hasChanges = response.changes
    @retryAfter = response.backoff or 0
