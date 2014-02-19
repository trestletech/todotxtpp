# This runs tests inside a Web Worker.

importScripts '../../../lib/dropbox.js'

importScripts '../../../test/vendor/sinon.js'
importScripts '../../../test/vendor/chai.js'
importScripts '../../../node_modules/sinon-chai/lib/sinon-chai.js'
importScripts '../../../node_modules/mocha/mocha.js'
importScripts '../../../test/js/helpers/browser_mocha_setup.js'

importScripts '../../../test/token/token.worker.js'
importScripts '../../../test/vendor/favicon.worker.js'
importScripts '../../../test/js/helpers/setup.js'

importScripts '../../../test/js/client_test.js'
# NOTE: not loading the auth driver tests, no driver works in a Web Worker.
importScripts '../../../test/js/fast/account_info_test.js'
importScripts '../../../test/js/fast/api_error_test.js'
importScripts '../../../test/js/fast/auth_driver/browser_test.js'
importScripts '../../../test/js/fast/auth_error_test.js'
importScripts '../../../test/js/fast/file/references_test.js'
importScripts '../../../test/js/fast/file/stat_test.js'
importScripts '../../../test/js/fast/http/app_info_test.js'
importScripts '../../../test/js/fast/http/pulled_changes_test.js'
importScripts '../../../test/js/fast/http/range_info_test.js'
importScripts '../../../test/js/fast/http/upload_cursor_test.js'
importScripts '../../../test/js/fast/util/base64_test.js'
importScripts '../../../test/js/fast/util/event_source_test.js'
importScripts '../../../test/js/fast/util/hmac_test.js'
importScripts '../../../test/js/fast/util/oauth_test.js'
importScripts '../../../test/js/fast/util/parse_date_test.js'
importScripts '../../../test/js/fast/util/xhr_test.js'
# NOTE: not loading web_worker_test.js, to allow Worker debugging with it.only

# NOTE: not loading helpers/browser_mocha_runner, using the code below instead.

# Fire the tests when we get the "go" message.
self.onmessage = (event) ->
  message = event.data
  switch message.type
    when 'go'
      self.testXhrServer = message.testXhrServer
      mocha.run()
