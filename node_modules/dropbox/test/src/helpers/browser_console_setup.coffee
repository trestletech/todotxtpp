# This lets us copy-paste code from test/src/helpers/setup.coffee
exports = window

delete exports.testKeys['secret']
delete exports.testFullDropboxKeys['secret']

window.client = new Dropbox.Client testKeys
console.log "Dropbox.Client instance exported as window.client"
