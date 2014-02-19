# Sets up an OAuth driver based on the current JavaScript environment.
#
# This method will not automatically configure the node.js driver due to
# security issues. node.js application must always use authDriver.
#
# @private
# This method is called by {Dropbox.Client#authorize} when no OAuth driver is
# set. It should not be called directly.
#
# @throw Error if the current enviornment does not support auto-configuration
Dropbox.AuthDriver.autoConfigure = (client) ->
  if typeof chrome isnt 'undefined' and chrome.runtime and chrome.runtime.id
    if chrome.tabs and chrome.tabs.create
      # Chrome extensions.
      client.authDriver new Dropbox.AuthDriver.ChromeExtension()
    else
      # Chrome packaged applications.
      client.authDriver new Dropbox.AuthDriver.ChromeApp()
    return

  if typeof window isnt 'undefined'
    if window.cordova
      # Cordova / PhoneGap applications.
      client.authDriver new Dropbox.AuthDriver.Cordova()
      return

    if window and window.navigator
      # Browser applications.
      client.authDriver new Dropbox.AuthDriver.Redirect()
      return
