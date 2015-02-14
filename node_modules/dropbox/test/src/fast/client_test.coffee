describe 'Dropbox.Client', ->
  beforeEach ->
    @client = new Dropbox.Client
      key: 'mock00key',
      token: 'mock00token',
      uid: 3141592,
      server: 'https://api$.no-calls-in-fasttests.com'

  describe 'with custom API server URLs', ->
    it 'computes the other URLs correctly', ->
      client = new Dropbox.Client
        key: 'mock00key',
        server: 'https://api$.sandbox.dropbox-proxy.com'

      expect(client._serverRoot).to.equal(
          'https://api$.sandbox.dropbox-proxy.com')
      expect(client._apiServer).to.match(
          /^https:\/\/api\d*\.sandbox\.dropbox-proxy\.com$/)
      expect(client._authServer).to.equal(
          'https://www.sandbox.dropbox-proxy.com')
      expect(client._fileServer).to.equal(
          'https://api-content.sandbox.dropbox-proxy.com')
      expect(client._notifyServer).to.equal(
          'https://api-notify.sandbox.dropbox-proxy.com')
      expect(client._downloadServer).to.equal(
          'https://dl.dropboxusercontent.com')

  describe '#_normalizePath', ->
    it "doesn't touch relative paths", ->
      expect(@client._normalizePath('aa/b/cc/dd')).to.equal 'aa/b/cc/dd'

    it 'removes the leading / from absolute paths', ->
      expect(@client._normalizePath('/aaa/b/cc/dd')).to.equal 'aaa/b/cc/dd'

    it 'removes multiple leading /s from absolute paths', ->
      expect(@client._normalizePath('///aa/b/ccc/dd')).to.equal 'aa/b/ccc/dd'

  describe '#_urlEncodePath', ->
    it 'encodes each segment separately', ->
      expect(@client._urlEncodePath('a b+c/d?e"f/g&h')).to.
          equal "a%20b%2Bc/d%3Fe%22f/g%26h"
    it 'normalizes paths', ->
      expect(@client._urlEncodePath('///a b+c/g&h')).to.
          equal "a%20b%2Bc/g%26h"

  describe '#dropboxUid', ->
    it 'matches the uid in the credentials', ->
      expect(@client.dropboxUid()).to.equal 3141592

  describe '#reset', ->
    beforeEach ->
      @authSteps = []
      @client.onAuthStepChange.addListener (client) =>
        @authSteps.push client.authStep
      @client.reset()

    it 'gets the client into the RESET state', ->
      expect(@client.authStep).to.equal Dropbox.Client.RESET

    it 'removes token and uid information', ->
      credentials = @client.credentials()
      expect(credentials).not.to.have.property 'token'
      expect(credentials).not.to.have.property 'uid'

    it 'triggers onAuthStepChange', ->
      expect(@authSteps).to.deep.equal [Dropbox.Client.RESET]

    it 'does not trigger onAuthStep if already reset', ->
      @authSteps.length = 0
      @client.reset()
      expect(@authSteps).to.deep.equal []

  describe '#credentials', ->
    it 'contains all the expected keys when DONE', ->
      credentials = @client.credentials()
      expect(credentials).to.have.property 'key'
      expect(credentials).to.have.property 'token'
      expect(credentials).to.have.property 'uid'

    it 'contains all the expected keys when RESET', ->
      @client.reset()
      credentials = @client.credentials()
      expect(credentials).to.have.property 'key'

    describe 'for a client with raw keys', ->
      beforeEach ->
        @client.setCredentials(
          key: 'dpf43f3p2l4k3l03', secret: 'kd94hf93k423kf44',
          token: 'user-token', uid: '1234567')

      it 'contains all the expected keys when DONE', ->
        credentials = @client.credentials()
        expect(credentials).to.have.property 'key'
        expect(credentials).to.have.property 'secret'
        expect(credentials).to.have.property 'token'
        expect(credentials).to.have.property 'uid'

      it 'contains all the expected keys when RESET', ->
        @client.reset()
        credentials = @client.credentials()
        expect(credentials).to.have.property 'key'
        expect(credentials).to.have.property 'secret'

    describe 'for a client with custom servers', ->
      beforeEach ->
        @client = new Dropbox.Client(
            key: 'mock00key',
            server: 'https://api$.sandbox.dropbox-proxy.com',
            downloadServer: 'https://dlserver.sandbox.dropbox-proxy.com')

      it 'contains the custom servers', ->
        credentials = @client.credentials()
        expect(credentials).to.have.property 'server'
        expect(credentials.server).to.equal(
            'https://api$.sandbox.dropbox-proxy.com')
        expect(credentials).to.have.property 'downloadServer'
        expect(credentials.downloadServer).to.equal(
            'https://dlserver.sandbox.dropbox-proxy.com')

  describe '#setCredentials', ->
    it 'gets the client into the RESET state', ->
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      expect(@client.authStep).to.equal Dropbox.Client.RESET
      credentials = @client.credentials()
      expect(credentials.key).to.equal 'app-key'
      expect(credentials.secret).to.equal 'app-secret'

    it 'gets the client into the DONE state', ->
      @client.setCredentials(
          key: 'app-key', secret: 'app-secret', token: 'user-token',
          uid: '3141592')
      expect(@client.authStep).to.equal Dropbox.Client.DONE
      credentials = @client.credentials()
      expect(credentials.key).to.equal 'app-key'
      expect(credentials.secret).to.equal 'app-secret'
      expect(credentials.token).to.equal 'user-token'
      expect(credentials.uid).to.equal '3141592'

    beforeEach ->
      @authSteps = []
      @client.onAuthStepChange.addListener (client) =>
        @authSteps.push client.authStep

    it 'triggers onAuthStepChange when switching from DONE to RESET', ->
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      expect(@authSteps).to.deep.equal [Dropbox.Client.RESET]

    it 'does not trigger onAuthStepChange when not switching', ->
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      @authSteps.length = 0
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      expect(@authSteps).to.deep.equal []

  describe '#authenticate', ->
    describe 'without an OAuth driver', ->
      beforeEach ->
        @stubbed = Dropbox.AuthDriver.autoConfigure
        @stubDriver =
          authType: -> 'token'
          url: -> 'http://stub.url/'
        Dropbox.AuthDriver.autoConfigure = (client) =>
          client.authDriver @stubDriver

      afterEach ->
        Dropbox.AuthDriver.autoConfigure = @stubbed

      it 'calls autoConfigure when no OAuth driver is supplied', (done) ->
        @client.reset()
        @client.authDriver null
        @stubDriver.doAuthorize = (authUrl, stateParam, client) =>
          expect(client).to.equal @client
          done()
        @client.authenticate null

      it 'raises an exception when AuthDriver.autoConfigure fails in RESET', ->
        @client.reset()
        expect(@client.authStep).to.equal Dropbox.Client.RESET
        @client.authDriver null
        @stubDriver = null
        expect(=> @client.authenticate null).to.
            throw Error, /auto-configuration failed/i

      it 'raises an exception when autoConfigure fails in AUTHORIZED', ->
        @client.setCredentials(
            key: 'app-key', secret: 'app-secret', oauthCode: 'auth-code')
        expect(@client.authStep).to.equal Dropbox.Client.AUTHORIZED
        @client.authDriver null
        @stubDriver = null
        expect(=> @client.authenticate null).to.
            throw Error, /auto-configuration failed/i

    it 'completes without an OAuth driver if already in DONE', (done) ->
      @client.authDriver null
      @client.authenticate (error, client) =>
        expect(error).to.equal null
        expect(client).to.equal @client
        done()

    it 'complains if called when the client is in ERROR', ->
      @client.authDriver doAuthorize: ->
        assert false, 'The OAuth driver should not be invoked'
      @client.authStep = Dropbox.Client.ERROR
      expect(=> @client.authenticate null).to.throw Error, /error.*reset/i

    describe 'with interactive: false', ->
      beforeEach ->
        @driver =
          doAuthorize: ->
            assert false, 'The OAuth driver should not be invoked'
          url: ->
            'https://localhost:8912/oauth_redirect'
        @client.authDriver @driver

      it 'stops at RESET with interactive: false', (done) ->
        @client.reset()
        @client.authenticate interactive: false, (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.RESET
          done()

      it 'stops at PARAM_SET with interactive: false', (done) ->
        @client.reset()
        @client._oauth.setAuthStateParam 'state_should_not_be_used'
        @client.authStep = @client._oauth.step()
        expect(@client.authStep).to.equal Dropbox.Client.PARAM_SET
        @client.authenticate interactive: false, (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.PARAM_SET
          done()

      it 'proceeds from PARAM_LOADED with interactive: false', (done) ->
        @client.reset()
        credentials = @client.credentials()
        credentials.oauthStateParam = 'state_should_not_be_used'
        @client.setCredentials credentials
        expect(@client.authStep).to.equal Dropbox.Client.PARAM_LOADED
        @client.authenticate interactive: false, (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.PARAM_SET
          done()

      it 'calls resumeAuthorize from PARAM_LOADED when defined', (done) ->
        @driver.resumeAuthorize = (stateParam, client, callback) ->
          expect(stateParam).to.equal 'state_should_not_be_used'
          expect(client.authStep).to.equal Dropbox.Client.PARAM_LOADED
          done()
        @client.reset()
        credentials = @client.credentials()
        credentials.oauthStateParam = 'state_should_not_be_used'
        @client.setCredentials credentials
        expect(@client.authStep).to.equal Dropbox.Client.PARAM_LOADED
        @client.authenticate (error, client) ->
          expect('callback_should_not_be_called').to.equal false
          done()

  describe '#signOut', ->
    describe 'without a token', ->
      beforeEach ->
        @client.reset()
      it 'throws an exception', ->
        expect(=> @client.signOut()).to.throw(Error, /client.*user.*token/i)

    describe 'with mustInvalidate', ->
      beforeEach ->
        @client.reset()
        @client.setCredentials token: 'fake-token'
        @onAuthStepChangeCalled = []
        @client.authDriver onAuthStepChange: (client, callback) =>
          @onAuthStepChangeCalled.push client.authStep
          callback()
        @xhrErrorMock = { status: 0 }
        @client._dispatchXhr = (xhr, callback) =>
          callback new Dropbox.ApiError(@xhrErrorMock, 'POST', 'url')

      describe 'unset', ->
        it 'ignores API server errors', (done) ->
          @client.signOff (error) =>
            expect(error).to.equal null
            expect(@onAuthStepChangeCalled).to.deep.equal(
                [Dropbox.Client.SIGNED_OUT])
            expect(@client.isAuthenticated()).to.equal false
            done()

      describe 'set to true', ->
        it 'aborts on API server errors', (done) ->
          @client.signOut mustInvalidate: true, (error) =>
            expect(error).to.be.instanceOf Dropbox.ApiError
            expect(error.status).to.equal 0
            expect(@onAuthStepChangeCalled.length).to.equal 0
            expect(@client.isAuthenticated()).to.equal true
            done()

        it 'succeeds if the API server says the token is invalid', (done) ->
          @xhrErrorMock.status = Dropbox.ApiError.INVALID_TOKEN
          @client.signOff mustInvalidate: true, (error) =>
            expect(error).to.equal null
            expect(@onAuthStepChangeCalled).to.deep.equal(
                [Dropbox.Client.SIGNED_OUT])
            expect(@client.isAuthenticated()).to.equal false
            done()

  describe '#constructor', ->
    it 'works with an access token and no API key', ->
      client = new Dropbox.Client token: '123'
      expect(client.authStep).to.equal Dropbox.Client.DONE

    it 'works with an API key', ->
      client = new Dropbox.Client key: 'key'
      expect(client.authStep).to.equal Dropbox.Client.RESET

    it 'throws an exception if initialized without an API key or token', ->
      expect(-> new Dropbox.Client({})).to.throw(Error, /no api key/i)

  describe '#_chooseApiServer', ->
    describe 'with only one API server', ->
      beforeEach ->
        @client = new Dropbox.Client(
            key: 'mock00key',
            server: 'https://api$.dropbox.com',
            maxApiServer: 0)

      it 'always returns that API server', ->
        for i in [1..10]
          expect(@client._chooseApiServer()).to.equal 'https://api.dropbox.com'

    describe 'with 10 API servers', ->
      beforeEach ->
        @client = new Dropbox.Client(
            key: 'mock00key',
            server: 'https://api$.dropbox.com',
            maxApiServer: 10)
        @stub = sinon.stub Math, 'random'

      afterEach ->
        @stub.restore()

      it 'can return the un-numbered server', ->
        @stub.returns 0.001
        expect(@client._chooseApiServer()).to.equal 'https://api.dropbox.com'

      it 'can return the 10th numbered server', ->
        @stub.returns 0.999
        expect(@client._chooseApiServer()).to.equal 'https://api10.dropbox.com'
