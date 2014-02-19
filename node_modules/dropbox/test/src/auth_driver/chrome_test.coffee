describe 'Dropbox.AuthDriver.ChromeBase', ->
  beforeEach ->
    @chrome = chrome?.runtime?.id
    @client = new Dropbox.Client testKeys

  describe '#loadCredentials', ->
    beforeEach ->
      return unless @chrome
      @client = new Dropbox.Client testKeys
      @driver = new Dropbox.AuthDriver.ChromeBase scope: 'some_scope'

    it 'produces the credentials passed to storeCredentials', (done) ->
      return done() unless @chrome
      goldCredentials = @client.credentials()
      @driver.storeCredentials goldCredentials, =>
        @driver = new Dropbox.AuthDriver.ChromeBase scope: 'some_scope'
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.deep.equal goldCredentials
          done()

    it 'produces null after forgetCredentials was called', (done) ->
      return done() unless @chrome
      @driver.storeCredentials @client.credentials(), =>
        @driver.forgetCredentials =>
          @driver = new Dropbox.AuthDriver.ChromeBase scope: 'some_scope'
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.equal null
            done()

    it 'produces null if a different scope is provided', (done) ->
      return done() unless @chrome
      @driver.storeCredentials @client.credentials(), =>
        @driver = new Dropbox.AuthDriver.ChromeBase scope: 'other_scope'
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.equal null
          done()

describe 'Dropbox.AuthDriver.ChromeApp', ->
  beforeEach ->
    @chrome = chrome?.runtime?.id
    @chrome_app = @chrome and chrome?.app?.window
    @client = new Dropbox.Client testKeys

  describe '#url', ->
    beforeEach ->
      return unless @chrome_app
      @driver = new Dropbox.AuthDriver.ChromeApp()

    it 'produces a chromiumapp.org url', ->
      return unless @chrome_app
      expect(@driver.url()).to.match(
          /https:\/\/[a-z0-9]+\.chromiumapp\.org\/$/)

  describe 'integration', ->
    it 'should work', (done) ->
      return done() unless @chrome_app
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.ChromeApp(
          scope: 'chrome_integration')
      client.authDriver authDriver
      authDriver.forgetCredentials ->
        client.authenticate (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.DONE
          # Verify that we can do API calls.
          client.getAccountInfo (error, accountInfo) ->
            expect(error).to.equal null
            expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
            # Follow-up authenticate() should use stored credentials.
            client.reset()
            client.authenticate interactive: false, (error, client) ->
              expect(error).to.equal null
              expect(client.authStep).to.equal Dropbox.Client.DONE
              expect(client.isAuthenticated()).to.equal true
              # Verify that we can do API calls.
              client.getAccountInfo (error, accountInfo) ->
                expect(error).to.equal null
                expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
                done()

    it 'should be the default driver in Chrome packaged apps', ->
      return unless @chrome_app
      client = new Dropbox.Client testKeys
      Dropbox.AuthDriver.autoConfigure client
      expect(client._driver).to.be.instanceOf Dropbox.AuthDriver.ChromeApp

describe 'Dropbox.AuthDriver.ChromeExtension', ->
  beforeEach ->
    @chrome = chrome?.runtime?.id
    @chrome_ext = @chrome and chrome?.tabs
    @client = new Dropbox.Client testKeys

  describe '#url', ->
    beforeEach ->
      return unless @chrome_ext
      @path = 'test/html/redirect_driver_test.html'
      @driver = new Dropbox.AuthDriver.ChromeExtension receiverPath: @path

    it 'produces a chrome-extension:// url', ->
      return unless @chrome_ext
      expect(@driver.url('oauth token')).to.match(/^chrome-extension:\/\//)

    it 'produces an URL with the correct suffix', ->
      return unless @chrome_ext
      url = @driver.url 'oauth token'
      expect(url.substring(url.length - @path.length)).to.equal @path

  describe 'integration', ->
    it 'should work', (done) ->
      return done() unless @chrome_ext
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.ChromeExtension(
          receiverPath: 'test/html/chrome_oauth_receiver.html',
          scope: 'chrome_integration')
      client.authDriver authDriver
      authDriver.forgetCredentials ->
        client.authenticate (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.DONE
          # Verify that we can do API calls.
          client.getAccountInfo (error, accountInfo) ->
            expect(error).to.equal null
            expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
            # Follow-up authenticate() should use stored credentials.
            client.reset()
            client.authenticate interactive: false, (error, client) ->
              expect(error).to.equal null
              expect(client.authStep).to.equal Dropbox.Client.DONE
              expect(client.isAuthenticated()).to.equal true
              # Verify that we can do API calls.
              client.getAccountInfo (error, accountInfo) ->
                expect(error).to.equal null
                expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
                done()

    it 'should be the default driver in Chrome extensions', ->
      return unless @chrome_ext
      client = new Dropbox.Client testKeys
      Dropbox.AuthDriver.autoConfigure client
      expect(client._driver).to.be.instanceOf(
          Dropbox.AuthDriver.ChromeExtension)
