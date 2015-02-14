# Wraps the description of a Dropbox Platform application.
#
# AppInfo instances contain the same information that is displayed on the
# OAuth authorize page, in a machine-friendly format.
#
# @see Dropbox.Client#appInfo
class Dropbox.Http.AppInfo
  # Creates an AppInfo instance from an /app/info API call result.
  #
  # @param {Object} appInfo the parsed JSON of an /app/info API call result
  # @param {String} appKey (optional) the app key used to make the/app/info API
  #   call; if missing, the key will be obtained from appInfo, or it will be
  #   null
  # @return {Dropbox.Http.AppInfo} an AppInfo instance wrapping the given info
  #   on a platform application
  @parse: (appInfo, appKey) ->
    if appInfo
      new Dropbox.Http.AppInfo appInfo, appKey
    else
      appInfo

  # @property {String} The application name entered in the app console.
  name: undefined

  # @property {String} The key used to fetch this application info.
  key: undefined

  # @property {Boolean} true if the application has access to the Datastore API
  canUseDatastores: undefined

  # @property {Boolean} true if the application has access to the Files API
  canUseFiles: undefined

  # @property {Boolean} true if the application has its own folder in the
  #   user's Dropbox
  hasAppFolder: undefined

  # @property {Boolean} true if the application has access to all the files in
  #   the user's Dropbox
  canUseFullDropbox: undefined

  # An icon that can be used as the application's logo.
  #
  # @param {Number} width the desired icon width
  # @param {Number} height (optional) the desired icon height; by default,
  #   equals the width argument
  icon: (width, height) ->
    height or= width
    @_icons["#{width}x#{height}"] or null

  # The width (and height) of small application icons.
  @ICON_SMALL: 64

  # The width (and height) of large application icons.
  @ICON_LARGE: 256

  # Creates a Dropbox.Http.AppInfo instance from an /app/info API call result.
  #
  # @private
  # This constructor is used by {Dropbox.Http.AppInfo.parse}, and should not be
  # called directly.
  #
  # @param {Object} appInfo the parsed JSON of an /app/info API call result
  # @param {String} appKey (optional) the app key used to make the/app/info API
  #   call; if missing, the key will be obtained from appInfo, or it will be
  #   null
  constructor: (appInfo, appKey) ->
    @name = appInfo.name
    @_icons = appInfo.icons

    permissions = appInfo.permissions or {}
    @canUseDatastores = !!permissions.datastores
    @canUseFiles = !!permissions.files
    @canUseFullDropbox = permissions.files is 'full_dropbox'
    @hasAppFolder = permissions.files is 'app_folder'

    if appKey
      @key = appKey
    else
      @key = appInfo.key or null
