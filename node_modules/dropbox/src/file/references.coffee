# Wraps an URL to a Dropbox file or folder that can be shared with other users.
#
# ShareUrl instances are created by calling {Dropbox.Client#makeUrl}. They can
# be safely shared with other users, as they do not contain the user's access
# token.
class Dropbox.File.ShareUrl
  # Creates a ShareUrl instance from a raw API response.
  #
  # @param {Object, String} urlData the parsed JSON describing a shared URL
  # @param {Boolean} isDirect true if this is a direct download link, false if
  #   it's a file / folder preview link
  # @return {Dropbox.File.ShareUrl} a ShareUrl instance wrapping the given
  #   shared URL information
  @parse: (urlData, isDirect) ->
    # NOTE: if the argument is not an object, it is returned; this makes the
    #       client code more compact
    if urlData and typeof urlData is 'object'
      new Dropbox.File.ShareUrl urlData, isDirect
    else
      urlData

  # @property {String} the public URL
  url: null

  # @property {Date} after this time, the URL is not usable
  expiresAt: null

  # @property {Boolean} true if this is a direct download URL, false for URLs
  #   to preview pages in the Dropbox web app; folders cannot have direct links
  #
  isDirect: null

  # @property {Boolean} true if this is URL points to a file's preview page in
  #   Dropbox, false for direct links
  isPreview: null

  # JSON representation of this file / folder's metadata
  #
  # @return {Object} an object that can be serialized using JSON; the object
  #   can be passed to {Dropbox.File.CopyReference.parse} to obtain a ShareUrl
  #   instance with the same information
  toJSON: ->
    # HACK: this can break if the Dropbox API ever decides to use 'direct' in
    #       its link info
    @_json ||= url: @url, expires: @expiresAt.toUTCString(), direct: @isDirect

  # @deprecated
  # @see Dropbox.File.ShareUrl#toJSON
  json: ->
    @toJSON()

  # Creates a ShareUrl instance from a raw API response.
  #
  # @private
  # This constructor is used by {Dropbox.File.ShareUrl.parse}, and should not
  # be called directly.
  #
  # @param {Object} urlData the parsed JSON describing a shared URL
  # @param {Boolean} isDirect true if this is a direct download link, false if
  #   is a file / folder preview link
  constructor: (urlData, isDirect) ->
    @url = urlData.url
    @expiresAt = Dropbox.Util.parseDate urlData.expires

    if isDirect is true
      @isDirect = true
    else if isDirect is false
      @isDirect = false
    else
      # HACK: this can break if the Dropbox API ever decides to use 'direct' in
      #       its link info; unfortunately, there's no elegant way to guess
      #       between direct download URLs and preview URLs
      if 'direct' of urlData
        @isDirect = urlData.direct
      else
        @isDirect = Date.now() - @expiresAt <= 86400000  # 1 day
    @isPreview = !@isDirect

    # The JSON representation is created on-demand, to avoid unnecessary object
    # creation.
    # We can't use the original JSON object because we add a 'direct' field.
    @_json = null

# Reference to a file that can be used to make a copy across users' Dropboxes.
class Dropbox.File.CopyReference
  # Creates a CopyReference instance from a raw reference or API response.
  #
  # @param {Object, String} refData the parsed JSON describing a copy
  #   reference, or the reference string
  # @return {Dropbox.File.CopyReference} a CopyReference instance wrapping the
  #   given reference
  @parse: (refData) ->
    # NOTE: if the argument is not an object or a string, it is returned; this
    #       makes the client code more compact
    if refData and (typeof refData is 'object' or typeof refData is 'string')
      new Dropbox.File.CopyReference refData
    else
      refData

  # @property {String} the raw reference, for use with Dropbox APIs
  tag: null

  # @property {Date} deadline for using the reference in a copy operation
  expiresAt: null

  # JSON representation of this file / folder's metadata
  #
  # @return {Object} an object that can be serialized using JSON; the object
  #   can be passed to {Dropbox.File.CopyReference.parse} to obtain a
  #   CopyReference instance with the same information
  toJSON: ->
    # NOTE: the assignment only occurs if the CopyReference was built around a
    #       string; CopyReferences parsed from API responses hold onto the
    #       original JSON
    @_json ||= copy_ref: @tag, expires: @expiresAt.toUTCString()

  # @deprecated
  # @see Dropbox.File.CopyReference#toJSON
  json: ->
    @toJSON()

  # Creates a CopyReference instance from a raw reference or API response.
  #
  # @private
  # This constructor is used by {Dropbox.File.CopyReference.parse}, and should
  # not be called directly.
  #
  # @param {Object, String} refData the parsed JSON describing a copy
  #   reference, or the reference string
  constructor: (refData) ->
    if typeof refData is 'object'
      @tag = refData.copy_ref
      @expiresAt = Dropbox.Util.parseDate(refData.expires)
      @_json = refData
    else
      @tag = refData
      @expiresAt = new Date Math.ceil(Date.now() / 1000) * 1000
      # The JSON representation is created on-demand, to avoid unnecessary
      # object creation.
      @_json = null
