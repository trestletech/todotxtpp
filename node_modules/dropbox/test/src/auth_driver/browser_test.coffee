describe 'Dropbox.AuthDriver.BrowserBase', ->
  beforeEach ->
    @node_js = module? and module?.exports? and require?
    @chrome_app = chrome?.runtime?.id
    @client = new Dropbox.Client testKeys

  describe 'with rememberUser: false', ->
    beforeEach (done) ->
      return done() if @node_js or @chrome_app
      @driver = new Dropbox.AuthDriver.BrowserBase rememberUser: false
      @driver.setStorageKey @client

      @scopedDriver = new Dropbox.AuthDriver.BrowserBase(
          rememberUser: false, scope: 'other')
      @scopedDriver.setStorageKey @client

      @driver.forgetCredentials =>
        @scopedDriver.forgetCredentials =>
          done()

    afterEach (done) ->
      return done() if @node_js or @chrome_app
      @driver.forgetCredentials =>
        @scopedDriver.forgetCredentials ->
          done()

    describe '#loadCredentials', ->
      it 'produces the credentials passed to storeCredentials', (done) ->
        return done() if @node_js or @chrome_app
        goldCredentials = @client.credentials()
        @driver.storeCredentials goldCredentials, =>
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.deep.equal goldCredentials
            done()

      it 'produces null after forgetCredentials was called', (done) ->
        return done() if @node_js or @chrome_app
        @driver.storeCredentials @client.credentials(), =>
          @driver.forgetCredentials =>
            @driver.loadCredentials (credentials) ->
              expect(credentials).to.equal null
              done()

      it 'produces null if a different scope is provided', (done) ->
        return done() if @node_js or @chrome_app
        goldCredentials = @client.credentials()
        @driver.storeCredentials goldCredentials, =>
          @scopedDriver.loadCredentials (credentials) =>
            expect(credentials).to.equal null
            @driver.loadCredentials (credentials) =>
              expect(credentials).to.deep.equal goldCredentials
              done()

  describe 'without localStorage support', ->
    beforeEach (done) ->
      return done() if @node_js or @chrome_app
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'localStorage'
      @stub.returns {}

      return done() if @node_js or @chrome_app
      @driver = new Dropbox.AuthDriver.BrowserBase rememberUser: false
      @driver.setStorageKey @client

      @scopedDriver = new Dropbox.AuthDriver.BrowserBase(
          rememberUser: false, scope: 'other')
      @scopedDriver.setStorageKey @client

      @driver.forgetCredentials =>
        @scopedDriver.forgetCredentials ->
          done()

    afterEach (done) ->
      return done() if @node_js or @chrome_app
      @stub.restore()
      @driver.forgetCredentials =>
        @scopedDriver.forgetCredentials ->
          done()

    describe '#loadCredentials', ->
      it 'produces the credentials passed to storeCredentials', (done) ->
        return done() if @node_js or @chrome_app
        goldCredentials = @client.credentials()
        @driver.storeCredentials goldCredentials, =>
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.deep.equal goldCredentials
            done()

      it 'works in the presence of other cookies', (done) ->
        return done() if @node_js or @chrome_app
        goldCredentials = @client.credentials()
        document.cookie = 'answer=42; path=/'
        @driver.storeCredentials goldCredentials, =>
          document.cookie = 'zzz_answer=42; path=/'
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.deep.equal goldCredentials
            done()

      it 'produces null after forgetCredentials was called', (done) ->
        return done() if @node_js or @chrome_app
        @driver.storeCredentials @client.credentials(), =>
          @driver.forgetCredentials =>
            @driver.loadCredentials (credentials) ->
              expect(credentials).to.equal null
              done()

      it 'produces null if a different scope is provided', (done) ->
        return done() if @node_js or @chrome_app
        goldCredentials = @client.credentials()
        @driver.storeCredentials goldCredentials, =>
          @scopedDriver.loadCredentials (credentials) =>
            expect(credentials).to.equal null
            @driver.loadCredentials (credentials) =>
              expect(credentials).to.deep.equal goldCredentials
              done()

    describe '#storeCredentials', ->
      it 'falls back to cookies', (done) ->
        return done() if @node_js or @chrome_app
        @driver.storeCredentials @client.credentials(), =>
          expect(document.cookie).to.contain 'dropbox-auth'
          done()

describe 'Dropbox.AuthDriver.Redirect', ->
  describe '#loadCredentials', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      return if @node_js or @chrome_app
      @client = new Dropbox.Client testKeys
      @driver = new Dropbox.AuthDriver.Redirect scope: 'some_scope'
      @driver.setStorageKey @client

    it 'produces the credentials passed to storeCredentials', (done) ->
      return done() if @node_js or @chrome_app
      goldCredentials = @client.credentials()
      @driver.storeCredentials goldCredentials, =>
        @driver = new Dropbox.AuthDriver.Redirect scope: 'some_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.deep.equal goldCredentials
          done()

    it 'produces null after forgetCredentials was called', (done) ->
      return done() if @node_js or @chrome_app
      @driver.storeCredentials @client.credentials(), =>
        @driver.forgetCredentials =>
          @driver = new Dropbox.AuthDriver.Redirect scope: 'some_scope'
          @driver.setStorageKey @client
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.equal null
            done()

    it 'produces null if a different scope is provided', (done) ->
      return done() if @node_js or @chrome_app
      @driver.setStorageKey @client
      @driver.storeCredentials @client.credentials(), =>
        @driver = new Dropbox.AuthDriver.Redirect scope: 'other_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.equal null
          done()

  describe 'integration', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      @cordova = cordova?

    it 'should work', (done) ->
      return done() if @node_js or @chrome_app or @cordova
      @timeout 45 * 1000  # Time-consuming because the user must click.

      listenerCalled = false
      listener = (event) ->
        window.removeEventListener 'message', listener
        Dropbox.AuthDriver.Popup.onMessage.removeListener listener
        return if listenerCalled is true
        listenerCalled = true
        data = event.data or event
        expect(data).to.match(/^\[.*\]$/)
        [error, credentials] = JSON.parse data
        expect(error).to.equal null
        expect(credentials).to.have.property 'uid'
        expect(credentials.uid).to.be.a 'string'
        expect(credentials).to.have.property 'token'
        expect(credentials.token).to.be.a 'string'
        done()

      window.addEventListener 'message', listener
      Dropbox.AuthDriver.Popup.onMessage.addListener listener
      (new Dropbox.AuthDriver.Popup()).openWindow(
          '/test/html/redirect_driver_test.html')

    it 'should be the default driver on browsers', ->
      return if @node_js or @chrome_app or @cordova
      client = new Dropbox.Client testKeys
      Dropbox.AuthDriver.autoConfigure client
      expect(client._driver).to.be.instanceOf Dropbox.AuthDriver.Redirect


describe 'Dropbox.AuthDriver.Popup', ->
  describe '#loadCredentials', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      return if @node_js or @chrome_app
      @client = new Dropbox.Client testKeys
      @driver = new Dropbox.AuthDriver.Popup scope: 'some_scope'
      @driver.setStorageKey @client

    it 'produces the credentials passed to storeCredentials', (done) ->
      return done() if @node_js or @chrome_app
      goldCredentials = @client.credentials()
      @driver.storeCredentials goldCredentials, =>
        @driver = new Dropbox.AuthDriver.Popup scope: 'some_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.deep.equal goldCredentials
          done()

    it 'produces null after forgetCredentials was called', (done) ->
      return done() if @node_js or @chrome_app
      @driver.storeCredentials @client.credentials(), =>
        @driver.forgetCredentials =>
          @driver = new Dropbox.AuthDriver.Popup scope: 'some_scope'
          @driver.setStorageKey @client
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.equal null
            done()

    it 'produces null if a different scope is provided', (done) ->
      return done() if @node_js or @chrome_app
      @driver.setStorageKey @client
      @driver.storeCredentials @client.credentials(), =>
        @driver = new Dropbox.AuthDriver.Popup scope: 'other_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.equal null
          done()

  describe 'integration', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      @cordova = cordova?

    it 'should work with rememberUser: false', (done) ->
      return done() if @node_js or @chrome_app or @cordova
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.Popup(
          receiverFile: 'oauth_receiver.html', scope: 'popup-integration',
          rememberUser: false)
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
      return done() if @node_js or @chrome_app or @cordova
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.Popup(
        receiverFile: 'oauth_receiver.html', scope: 'popup-integration',
        rememberUser: true)
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
