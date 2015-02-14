# Tracks the progress of a resumable upload.
class Dropbox.Http.UploadCursor
  # Creates an UploadCursor instance from an API response.
  #
  # @param {Object, String} cursorData the parsed JSON describing the status
  #   of a partial upload, or the upload ID string
  # @return {Dropbox.Http.UploadCursor} an UploadCursor instance wrapping the
  #   given cursor information
  @parse: (cursorData) ->
    # NOTE: if the argument is not an object or string, it is returned; this
    #       makes the client code more compact
    if cursorData and (typeof cursorData is 'object' or
                       typeof cursorData is 'string')
      new Dropbox.Http.UploadCursor cursorData
    else
      cursorData

  # @property {String} the server-generated ID for this upload
  tag: null

  # @property {Number} number of bytes that have already been uploaded
  offset: null

  # @property {Date} deadline for finishing the upload
  expiresAt: null

  # JSON representation of this cursor.
  #
  # @return {Object} an object that can be serialized using JSON; the object
  #   can be passed to {Dropbox.Http.UploadCursor.parse} to obtain an
  #   UploadCursor instance with the same information
  toJSON: ->
    # NOTE: the assignment only occurs if
    @_json ||=
        upload_id: @tag, offset: @offset, expires: @expiresAt.toUTCString()

  # @deprecated
  # @see Dropbox.Http.UploadCursor#toJSON
  json: ->
    @toJSON()

  # Creates an UploadCursor instance from a raw reference or API response.
  #
  # This constructor should only be called directly to obtain a cursor for a
  # new file upload. {Dropbox.Http.UploadCursor.parse} should be preferred for
  # any other use.
  #
  # @param {Object, String} cursorData the parsed JSON describing a copy
  #   reference, or the reference string
  constructor: (cursorData) ->
    @replace cursorData

  # Replaces the data in this UploadCursor with the data in an API response.
  #
  # @private
  # This should only be used by {Dropbox.Client#resumableUploadStep}.
  #
  # @param {Object, String} cursorData the parsed JSON describing a copy
  #   reference, or the reference string; if null, this UploadCursor instance
  #   is reset, and can be used to start a new upload
  # @return {Dropbox.Http.UploadCursor} this
  replace: (cursorData) ->
    if typeof cursorData is 'object'
      @tag = cursorData.upload_id or null
      @offset = cursorData.offset or 0
      @expiresAt = Dropbox.Util.parseDate(cursorData.expires) or Date.now()
      @_json = cursorData
    else
      @tag = cursorData or null
      @offset = 0
      @expiresAt = new Date Math.floor(Date.now() / 1000) * 1000
      @_json = null
    @
