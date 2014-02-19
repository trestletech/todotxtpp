describe 'Dropbox.AuthDriver.Cordova', ->
  describe '#url', ->
    beforeEach ->
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'currentLocation'
      @stub.returns 'http://test:123/a/path/file.htmx'

    afterEach ->
      @stub.restore()

    it 'uses a dropbox.com redirect URL', ->
      driver = new Dropbox.AuthDriver.Cordova
      expect(driver.url()).to.match(/dropbox\.com/)

  describe '#loadCredentials', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      return if @node_js or @chrome_app
      @client = new Dropbox.Client testKeys
      @driver = new Dropbox.AuthDriver.Cordova scope: 'some_scope'
      @driver.setStorageKey @client

    it 'produces the credentials passed to storeCredentials', (done) ->
      return done() if @node_js or @chrome_app
      goldCredentials = @client.credentials()
      @driver.storeCredentials goldCredentials, =>
        @driver = new Dropbox.AuthDriver.Cordova scope: 'some_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.deep.equal goldCredentials
          done()

    it 'produces null after forgetCredentials was called', (done) ->
      return done() if @node_js or @chrome_app
      @driver.storeCredentials @client.credentials(), =>
        @driver.forgetCredentials =>
          @driver = new Dropbox.AuthDriver.Cordova scope: 'some_scope'
          @driver.setStorageKey @client
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.equal null
            done()

    it 'produces null if a different scope is provided', (done) ->
      return done() if @node_js or @chrome_app
      @driver.setStorageKey @client
      @driver.storeCredentials @client.credentials(), =>
        @driver = new Dropbox.AuthDriver.Cordova scope: 'other_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.equal null
          done()

  describe 'integration', ->
    beforeEach ->
      @cordova = cordova?

    it 'should work with rememberUser: false', (done) ->
      return done() unless @cordova
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.Cordova(
          scope: 'cordova-integration', rememberUser: false)
      client.authDriver authDriver
      client.authenticate (error, client) =>
        expect(error).to.equal null
        expect(client.authStep).to.equal Dropbox.Client.DONE
        # Verify that we can do API calls.
        client.getAccountInfo (error, accountInfo) ->
          expect(error).to.equal null
          expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo

          # Follow-up authenticate() should restart the process.
          client.reset()
          client.authenticate interactive: false, (error, client) ->
            expect(error).to.equal null
            expect(client.authStep).to.equal Dropbox.Client.RESET
            expect(client.isAuthenticated()).to.equal false
            done()

    it 'should work with rememberUser: true', (done) ->
      return done() unless @cordova
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.Cordova(
          scope: 'cordova-integration', rememberUser: true)
      client.authDriver authDriver
      authDriver.setStorageKey client
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

    it 'should be the default driver on Cordova', ->
      return unless @cordova
      client = new Dropbox.Client testKeys
      Dropbox.AuthDriver.autoConfigure client
      expect(client._driver).to.be.instanceOf Dropbox.AuthDriver.Cordova
