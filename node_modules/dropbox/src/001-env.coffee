if typeof global isnt 'undefined' and typeof module isnt 'undefined' and
    'exports' of module
  # Running inside node.js.
  DbxEnvGlobal = global
  DbxEnvRequire = module.require.bind module
  module.exports = Dropbox

else if typeof window isnt 'undefined' and typeof navigator isnt 'undefined'
  # Running inside a browser.
  DbxEnvGlobal = window
  DbxEnvRequire = null
  if window.Dropbox
    # Someone's stepping on our toes. It's most likely the Chooser library.
    do ->
      Dropbox[name] = value for own name, value of window.Dropbox
  window.Dropbox = Dropbox

else if typeof self isnt 'undefined' and typeof navigator isnt 'undefined'
  # Running inside a Web worker.
  DbxEnvGlobal = self
  # NOTE: browsers that implement Web Workers also implement the ES5 bind.
  DbxEnvRequire = self.importScripts.bind self
  self.Dropbox = Dropbox

else
  throw new Error 'dropbox.js loaded in an unsupported JavaScript environment.'


# Helpers for interacting with the JavaScript environment we run in.
#
# @private
class Dropbox.Env
  # The global environment object.
  @global: DbxEnvGlobal

  # Loads a module into the JavaScript environment.
  #
  # This is null in the browser. It is aliased to require in node.js and to
  # importScripts in Web Workers.
  @require: DbxEnvRequire
