# Information about a Dropbox user account.
class Dropbox.AccountInfo
  # Creates an AccountInfo instance from a raw API response.
  #
  # @param {Object} accountInfo the result of parsing a JSON API response that
  #   describes a user account
  # @return {Dropbox.AccountInfo} an AccountInfo instance wrapping the given
  #   API response
  @parse: (accountInfo) ->
    # NOTE: if the argument is not an object, it is returned; this makes the
    #       client code more compact
    if accountInfo and typeof accountInfo is 'object'
      new Dropbox.AccountInfo accountInfo
    else
      accountInfo

  # @property {String} the user's name, in a form that is fit for display
  name: null

  # @property {String} the user's email, or null if unavailable
  email: null

  # @property {String} two-letter country code, or null if unavailable
  countryCode: null

  # @property {String} unique ID for the user; this ID matches the unique ID
  #   returned by the authentication process
  uid: null

  # @property {String} the user's referral link; the user might benefit if
  #   others use the link to sign up for Dropbox
  referralUrl: null

  # Specific to applications whose access type is "public app folder".
  #
  # @property {String} prefix for URLs to the application's files
  publicAppUrl: null

  # @property {Number} the maximum amount of bytes that the user can store
  quota: null

  # @property {Number} the number of bytes taken up by the user's data
  usedQuota: null

  # @property {Number} the number of bytes taken up by the user's data that is
  #   not shared with other users
  privateBytes: null

  # @property {Number} the number of bytes taken up by the user's data that is
  #   shared with other users
  sharedBytes: null

  # JSON representation of this user's information.
  #
  # @return {Object} an object that can be serialized using JSON; the object
  #   can be passed to {Dropbox.AccountInfo.parse} to obtain an AccountInfo
  #   instance with the same information
  json: ->
    @_json

  # Creates a AccountInfo instance from a raw API response.
  #
  # @private
  # This constructor is used by {Dropbox.AccountInfo.parse}, and should not be
  # called directly.
  #
  # @param {Object} accountInfo the result of parsing a JSON API response that
  #   describes a user
  constructor: (accountInfo) ->
    @_json = accountInfo
    @name = accountInfo.display_name
    @email = accountInfo.email
    @countryCode = accountInfo.country or null
    @uid = accountInfo.uid.toString()
    if accountInfo.public_app_url
      @publicAppUrl = accountInfo.public_app_url
      lastIndex = @publicAppUrl.length - 1
      # Strip any trailing /, to make path joining predictable.
      if lastIndex >= 0 and @publicAppUrl.substring(lastIndex) is '/'
        @publicAppUrl = @publicAppUrl.substring 0, lastIndex
    else
      @publicAppUrl = null

    @referralUrl = accountInfo.referral_link
    @quota = accountInfo.quota_info.quota
    @privateBytes = accountInfo.quota_info.normal or 0
    @sharedBytes = accountInfo.quota_info.shared or 0
    @usedQuota = @privateBytes + @sharedBytes

