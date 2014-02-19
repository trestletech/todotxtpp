# Wraps the result of pullChanges, describing the changes in a user's Dropbox.
#
# @see Dropbox.Client#pullChanges
class Dropbox.Http.PulledChanges
  # Creates a PulledChanges instance from a /delta API call result.
  #
  # @param {Object} deltaInfo the parsed JSON of a /delta API call result
  # @return {Dropbox.Http.PulledChanges} a PulledChanges instance wrapping the
  #   given Dropbox changes
  @parse: (deltaInfo) ->
    # NOTE: if the argument is not an object, it is returned; this makes the
    #       client code more compact
    if deltaInfo and typeof deltaInfo is 'object'
      new Dropbox.Http.PulledChanges deltaInfo
    else
      deltaInfo

  # @property {Boolean} if true, the application should reset its copy of the
  #   user's Dropbox before applying the changes described by this instance
  blankSlate: undefined

  # @property {String} encodes a cursor in the list of changes to a user's
  #   Dropbox; a pullChanges call returns some changes at the cursor, and then
  #   advance the cursor to account for the returned changes; the new cursor is
  #   returned by pullChanges, and meant to be used by a subsequent pullChanges
  #   call
  cursorTag: undefined

  # @property {Array<Dropbox.Http.PulledChange> an array with one entry for
  #   each change to the user's Dropbox returned by a pullChanges call
  changes: undefined

  # @property {Boolean} if true, the pullChanges call returned a subset of the
  #   available changes, and the application should repeat the call
  #   immediately to get more changes
  shouldPullAgain: undefined

  # @property {Boolean} if true, the API call will not have any more changes
  #   available in the nearby future, so the application should wait for at
  #   least 5 minutes before issuing another pullChanges request
  shouldBackOff: undefined

  # Serializable representation of the pull cursor inside this object.
  #
  # @return {String} an ASCII string that can be passed to pullChanges instead
  #   of this PulledChanges instance
  cursor: -> @cursorTag

  # Creates a Dropbox.Http.PulledChanges from a /delta API call result.
  #
  # @private
  # This constructor is used by {Dropbox.Http.PulledChanges.parse}, and should
  # not be called directly.
  #
  # @param {Object} deltaInfo the parsed JSON of a /delta API call result
  constructor: (deltaInfo) ->
    @blankSlate = deltaInfo.reset or false
    @cursorTag = deltaInfo.cursor
    @shouldPullAgain = deltaInfo.has_more
    @shouldBackOff = not @shouldPullAgain
    if deltaInfo.cursor and deltaInfo.cursor.length
      @changes = for entry in deltaInfo.entries
        Dropbox.Http.PulledChange.parse entry
    else
      @changes = []

# Wraps a single change in a pullChanges result.
#
# @see Dropbox.Client#pullChanges
class Dropbox.Http.PulledChange
  # Creates a PulledChange instance wrapping an entry in a /delta result.
  #
  # @param {Object} entry the parsed JSON of a single entry in a /delta API
  #   call result
  # @return {Dropbox.Http.PulledChange} a PulledChange instance wrapping the
  #   given entry of a /delta API call response
  @parse: (entry) ->
    # NOTE: if the argument is not an object, it is returned; this makes the
    #       client code more compact
    if entry and typeof entry is 'object'
      new Dropbox.Http.PulledChange entry
    else
      entry

  # @property {String} the path of the changed file or folder
  path: undefined

  # @property {Boolean} if true, this change is a deletion of the file or
  #   folder at the change's path; if a folder is deleted, all its contents
  #   (files and sub-folders) were also be deleted; pullChanges might not
  #   return separate changes expressing for the files or sub-folders
  wasRemoved: undefined

  # @property {Dropbox.File.Stat} a Stat instance containing updated
  #   information for the file or folder; this is null if the change is a
  #   deletion
  stat: undefined

  # Creates a PulledChange instance wrapping an entry in a /delta result.
  #
  # @private
  # This constructor is used by {Dropbox.Http.PulledChange.parse}, and should
  # not be called directly.
  #
  # @param {Object} entry the parsed JSON of a single entry in a /delta API
  #   call result
  constructor: (entry) ->
    @path = entry[0]
    @stat = Dropbox.File.Stat.parse entry[1]
    if @stat
      @wasRemoved = false
    else
      @stat = null
      @wasRemoved = true

# Wraps a {Dropbox.Client#pollForChanges} response.
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

