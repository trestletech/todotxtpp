describe 'Dropbox.Util.Oauth', ->
  beforeEach ->
    @method = 'GET'
    @url = '/photos'
    @params = answer: 42, other: 43
    @timestamp = 1370129543574

  buildSecretlessTransitionTests = ->
    describe '#setAuthStateParam', ->
      beforeEach ->
        @oauth.setAuthStateParam 'oauth-state'

      it 'makes #step return PARAM_SET', ->
        expect(@oauth.step()).to.equal Dropbox.Client.PARAM_SET

      it 'adds the param to credentials', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', oauthStateParam: 'oauth-state')

    describe '#processRedirectParams', ->
      it 'returns true when the query params contain a code', ->
        expect(@oauth.processRedirectParams(code: 'authorization-code')).
            to.equal true

      it 'returns true when the query params contain a token', ->
        expect(@oauth.processRedirectParams(
            token_type: 'Bearer', access_token: 'access-token')).
            to.equal true

      it 'returns true when the query params contain a error', ->
        expect(@oauth.processRedirectParams(error: 'access_denied')).
            to.equal true

      it 'throws an exception on unimplemented token types', ->
        expect(=> @oauth.processRedirectParams(token_type: 'unimplemented')).
            to.throw(Error, /unimplemented token/i)

      it "returns false when the query params don't contain a code/token", ->
        expect(@oauth.processRedirectParams(random_param: 'random')).
            to.equal false

      describe 'with an authorization code', ->
        beforeEach ->
          @oauth.processRedirectParams code: 'authorization-code'

        it 'makes #step return AUTHORIZED', ->
          expect(@oauth.step()).to.equal Dropbox.Client.AUTHORIZED

        it 'adds the code to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              key: 'client-id', oauthCode: 'authorization-code')

      describe 'with a Bearer token', ->
        beforeEach ->
          @oauth.processRedirectParams(
              token_type: 'Bearer', access_token: 'bearer-token')

        it 'makes #step return DONE', ->
          expect(@oauth.step()).to.equal Dropbox.Client.DONE

        it 'adds the token to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              key: 'client-id', token: 'bearer-token')

      describe 'with a MAC token', ->
        beforeEach ->
          @oauth.processRedirectParams(
              token_type: 'mac', access_token: 'mac-token',
              kid: 'mac-server-kid', mac_key: 'mac-token-key',
              mac_algorithm: 'hmac-sha-1')

        it 'makes #step() return DONE', ->
          expect(@oauth.step()).to.equal Dropbox.Client.DONE

        it 'adds the token to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              key: 'client-id', token: 'mac-token', tokenKid: 'mac-server-kid',
              tokenKey: 'mac-token-key')

      describe 'with an OAuth error response', ->
        beforeEach ->
          @oauth.processRedirectParams(
              error: 'access_denied',
              error_description: "The application didn't seem trustworthy")

        it 'makes #step() return ERROR', ->
          expect(@oauth.step()).to.equal Dropbox.Client.ERROR

        it 'preserves the api key in the credentials', ->
          expect(@oauth.credentials()).to.deep.equal key: 'client-id'

        it 'makes #error() return the error', ->
          error = @oauth.error()
          expect(error).to.be.instanceOf Dropbox.AuthError
          expect(error.code).to.equal Dropbox.AuthError.ACCESS_DENIED
          expect(error.description).to.equal(
              "The application didn't seem trustworthy")

        it 'lets #reset() return to RESET', ->
          @oauth.reset()
          expect(@oauth.step()).to.equal Dropbox.Client.RESET

      describe 'without a code or token', ->
        beforeEach ->
          @oldStep = @oauth.step()
          @oauth.processRedirectParams random_param: 'random'

        it 'does not change the auth step', ->
          expect(@oauth.step()).to.equal @oldStep

    describe '#reset', ->
      beforeEach ->
        @oauth.reset()

      it 'makes #step() return RESET', ->
        expect(@oauth.step()).to.equal Dropbox.Client.RESET

  buildSecretTransitionTests = ->
    describe '#setAuthStateParam', ->
      beforeEach ->
        @oauth.setAuthStateParam 'oauth-state'

      it 'makes #step return PARAM_SET', ->
        expect(@oauth.step()).to.equal Dropbox.Client.PARAM_SET

      it 'adds the param to credentials', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', secret: 'client-secret',
            oauthStateParam: 'oauth-state')

    describe '#processRedirectParams', ->
      it 'returns true when the query params contain a code', ->
        expect(@oauth.processRedirectParams(code: 'authorization-code')).
            to.equal true

      it 'returns true when the query params contain a token', ->
        expect(@oauth.processRedirectParams(
            token_type: 'Bearer', access_token: 'access-token')).
            to.equal true

      it 'returns true when the query params contain a error', ->
        expect(@oauth.processRedirectParams(error: 'access_denied')).
            to.equal true

      it 'throws an exception on unimplemented token types', ->
        expect(=> @oauth.processRedirectParams(token_type: 'unimplemented')).
            to.throw(Error, /unimplemented token/i)

      it "returns false when the query params don't contain a code/token", ->
        expect(@oauth.processRedirectParams(random_param: 'random')).
            to.equal false

      describe 'with an authorization code', ->
        beforeEach ->
          @oauth.processRedirectParams code: 'authorization-code'

        it 'makes #step return AUTHORIZED', ->
          expect(@oauth.step()).to.equal Dropbox.Client.AUTHORIZED

        it 'adds the code to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              key: 'client-id', secret: 'client-secret',
              oauthCode: 'authorization-code')

      describe 'with a Bearer token', ->
        beforeEach ->
          @oauth.processRedirectParams(
              token_type: 'Bearer', access_token: 'bearer-token')

        it 'makes #step return DONE', ->
          expect(@oauth.step()).to.equal Dropbox.Client.DONE

        it 'adds the token to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              key: 'client-id', secret: 'client-secret', token: 'bearer-token')

      describe 'with a MAC token', ->
        beforeEach ->
          @oauth.processRedirectParams(
              token_type: 'mac', access_token: 'mac-token',
              kid: 'mac-server-kid', mac_key: 'mac-token-key',
              mac_algorithm: 'hmac-sha-1')

        it 'makes #step return DONE', ->
          expect(@oauth.step()).to.equal Dropbox.Client.DONE

        it 'adds the token to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              key: 'client-id', secret: 'client-secret',
              token: 'mac-token', tokenKid: 'mac-server-kid',
              tokenKey: 'mac-token-key')

      describe 'with an OAuth error response', ->
        beforeEach ->
          @oauth.processRedirectParams(
              error: 'access_denied',
              error_description: "The application didn't seem trustworthy")

        it 'makes #step() return ERROR', ->
          expect(@oauth.step()).to.equal Dropbox.Client.ERROR

        it 'preserves the app key and secret in the credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              key: 'client-id', secret: 'client-secret')

        it 'lets #reset() return to RESET', ->
          @oauth.reset()
          expect(@oauth.step()).to.equal Dropbox.Client.RESET

      describe 'without a code or token', ->
        beforeEach ->
          @oldStep = @oauth.step()
          @oauth.processRedirectParams random_param: 'random'

        it 'does not change the step', ->
          expect(@oauth.step()).to.equal @oldStep

    describe '#reset', ->
      beforeEach ->
        @oauth.reset()

      it 'makes #step() return RESET', ->
        expect(@oauth.step()).to.equal Dropbox.Client.RESET

  buildKeylessTransitionTests = ->
    describe '#setAuthStateParam', ->
      it 'throws an exception', ->
        expect(=> @oauth.setAuthStateParam('oauth-state')).to.throw(
            Error, /no api key/i)

    describe '#processRedirectParams', ->
      it 'throws an exception when the query params contain a code', ->
        expect(=> @oauth.processRedirectParams(code: 'authorization-code')).
            to.throw(Error, /no api key/i)

      it 'returns true when the query params contain a token', ->
        expect(@oauth.processRedirectParams(
            token_type: 'Bearer', access_token: 'access-token')).
            to.equal true

      it 'throws an exeception when the query params contain a error', ->
        expect(=> @oauth.processRedirectParams(error: 'access_denied')).
            to.throw(Error, /no api key/i)

      it 'throws an exception on unimplemented token types', ->
        expect(=> @oauth.processRedirectParams(token_type: 'unimplemented')).
            to.throw(Error, /unimplemented token/i)

      it "returns false when the query params don't contain a code/token", ->
        expect(@oauth.processRedirectParams(random_param: 'random')).
            to.equal false

      describe 'with a Bearer token', ->
        beforeEach ->
          @oauth.processRedirectParams(
              token_type: 'Bearer', access_token: 'bearer-token')

        it 'makes #step return DONE', ->
          expect(@oauth.step()).to.equal Dropbox.Client.DONE

        it 'adds the token to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(token: 'bearer-token')

      describe 'with a MAC token', ->
        beforeEach ->
          @oauth.processRedirectParams(
              token_type: 'mac', access_token: 'mac-token',
              kid: 'mac-server-kid', mac_key: 'mac-token-key',
              mac_algorithm: 'hmac-sha-1')

        it 'makes #step() return DONE', ->
          expect(@oauth.step()).to.equal Dropbox.Client.DONE

        it 'adds the token to credentials', ->
          expect(@oauth.credentials()).to.deep.equal(
              token: 'mac-token', tokenKid: 'mac-server-kid',
              tokenKey: 'mac-token-key')

      describe 'without a code or token', ->
        beforeEach ->
          @oldStep = @oauth.step()
          @oauth.processRedirectParams random_param: 'random'

        it 'does not change the auth step', ->
          expect(@oauth.step()).to.equal @oldStep

    describe '#reset', ->
      beforeEach ->
        @oauth.reset()

      it 'makes #step() return RESET', ->
        expect(@oauth.step()).to.equal Dropbox.Client.RESET

  describe 'with an app key', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth key: 'client-id'

    describe '#credentials', ->
      it 'returns the app key', ->
        expect(@oauth.credentials()).to.deep.equal key: 'client-id'

    describe '#step', ->
      it 'returns RESET', ->
        expect(@oauth.step()).to.equal Dropbox.Client.RESET

    describe '#authHeader', ->
      it 'uses HTTP Basic authentication with the client id and no pw', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Basic Y2xpZW50LWlkOg==')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the client id', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            client_id: 'client-id', answer: 42, other: 43)

    describe '#checkAuthStateParam', ->
      it 'returns false for null', ->
        expect(@oauth.checkAuthStateParam(null)).to.equal false

    buildSecretlessTransitionTests()

  describe 'with an app key and secret', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth key: 'client-id', secret: 'client-secret'

    describe '#credentials', ->
      it 'returns the app key', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', secret: 'client-secret')

    describe '#step', ->
      it 'returns RESET', ->
        expect(@oauth.step()).to.equal Dropbox.Client.RESET

    describe '#authHeader', ->
      it 'uses HTTP Basic authentication with the client id and secret', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Basic Y2xpZW50LWlkOmNsaWVudC1zZWNyZXQ=')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the client id', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            client_id: 'client-id', client_secret: 'client-secret',
            answer: 42, other: 43)

    describe '#checkAuthStateParam', ->
      it 'returns false for null', ->
        expect(@oauth.checkAuthStateParam(null)).to.equal false

    buildSecretTransitionTests()

  describe 'with an app key and state param', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth(
          key: 'client-id', oauthStateParam: 'oauth-state')

    describe '#credentials', ->
      it 'returns the app key and state param', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', oauthStateParam: 'oauth-state')

    describe '#step', ->
      it 'returns PARAM_LOADED', ->
        expect(@oauth.step()).to.equal Dropbox.Client.PARAM_LOADED

    describe '#checkAuthStateParam', ->
      it 'returns true for the correct param', ->
        expect(@oauth.checkAuthStateParam('oauth-state')).to.equal true

      it 'returns false for the wrong param', ->
        expect(@oauth.checkAuthStateParam('not-oauth-state')).to.equal false

      it 'returns false for null', ->
        expect(@oauth.checkAuthStateParam(null)).to.equal false

    describe '#authorizeUrlParams', ->
      beforeEach ->
        @url = 'http://redirect.to/here'

      describe 'with token responseType', ->
        it 'asks for an access token', ->
          expect(@oauth.authorizeUrlParams('token', @url)).to.deep.equal(
              client_id: 'client-id', state: 'oauth-state',
              response_type: 'token', redirect_uri: @url)

      describe 'with code responseType', ->
        it 'asks for an authorization code', ->
          expect(@oauth.authorizeUrlParams('code', @url)).to.deep.equal(
              client_id: 'client-id', state: 'oauth-state',
              response_type: 'code', redirect_uri: @url)

      describe 'with an un-implemented responseType', ->
        it 'throws an Error', ->
          expect(=> @oauth.authorizeUrlParams('other', @url)).to.
              throw(Error, /unimplemented .* response type/i)

    describe '#authHeader', ->
      it 'uses HTTP Basic authentication with the client id and no pw', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Basic Y2xpZW50LWlkOg==')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the client id', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            client_id: 'client-id', answer: 42, other: 43)

    buildSecretlessTransitionTests()

  describe 'with an app key + secret and state param', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth(
        key: 'client-id', secret: 'client-secret',
        oauthStateParam: 'oauth-state')

    describe '#credentials', ->
      it 'returns the app key + secret and state param', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', secret: 'client-secret',
            oauthStateParam: 'oauth-state')

    describe '#step', ->
      it 'returns PARAM_LOADED', ->
        expect(@oauth.step()).to.equal Dropbox.Client.PARAM_LOADED

    describe '#checkAuthStateParam', ->
      it 'returns true for the correct param', ->
        expect(@oauth.checkAuthStateParam('oauth-state')).to.equal true

      it 'returns false for the wrong param', ->
        expect(@oauth.checkAuthStateParam('not-oauth-state')).to.equal false

      it 'returns false for null', ->
        expect(@oauth.checkAuthStateParam(null)).to.equal false

    describe '#authorizeUrlParams', ->
      beforeEach ->
        @url = 'http://redirect.to/here'

      describe 'with token responseType', ->
        it 'asks for an access token', ->
          expect(@oauth.authorizeUrlParams('token', @url)).to.deep.equal(
              client_id: 'client-id', state: 'oauth-state',
              response_type: 'token', redirect_uri: @url)

      describe 'with code responseType', ->
        it 'asks for an authorization code', ->
          expect(@oauth.authorizeUrlParams('code', @url)).to.deep.equal(
              client_id: 'client-id', state: 'oauth-state',
              response_type: 'code', redirect_uri: @url)

      describe 'with an un-implemented responseType', ->
        it 'throws an Error', ->
          expect(=> @oauth.authorizeUrlParams('other', @url)).to.
              throw(Error, /unimplemented .* response type/i)

    describe '#authHeader', ->
      it 'uses HTTP Basic authentication with the id as the username', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Basic Y2xpZW50LWlkOmNsaWVudC1zZWNyZXQ=')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the client id', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            client_id: 'client-id', client_secret: 'client-secret',
            answer: 42, other: 43)

    buildSecretTransitionTests()

  describe 'with an app key and authorization code', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth key: 'client-id', oauthCode: 'auth-code'

    describe '#credentials', ->
      it 'returns the app key and authorization code', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', oauthCode: 'auth-code')

    describe '#step', ->
      it 'returns AUTHORIZED', ->
        expect(@oauth.step()).to.equal Dropbox.Client.AUTHORIZED

    describe '#accessTokenParams', ->
      describe 'without a redirect URL', ->
        it 'matches the spec', ->
          expect(@oauth.accessTokenParams()).to.deep.equal(
              grant_type: 'authorization_code', code: 'auth-code')

      describe 'with a redirect URL', ->
        it 'matches the spec and includes the URL', ->
          url = 'http://redirect.to/here'
          expect(@oauth.accessTokenParams(url)).to.deep.equal(
              grant_type: 'authorization_code', code: 'auth-code',
              redirect_uri: url)

    describe '#authHeader', ->
      it 'uses HTTP Basic authentication with the client id and no pw', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Basic Y2xpZW50LWlkOg==')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the client id', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            client_id: 'client-id', answer: 42, other: 43)

    buildSecretlessTransitionTests()

  describe 'with an app key + secret and authorization code', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth(
        key: 'client-id', secret: 'client-secret', oauthCode: 'auth-code')

    describe '#credentials', ->
      it 'returns the app key + secret and state param', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', secret: 'client-secret', oauthCode: 'auth-code')

    describe '#step', ->
      it 'returns AUTHORIZED', ->
        expect(@oauth.step()).to.equal Dropbox.Client.AUTHORIZED

    describe '#accessTokenParams', ->
      describe 'without a redirect URL', ->
        it 'matches the spec', ->
          expect(@oauth.accessTokenParams()).to.deep.equal(
              grant_type: 'authorization_code', code: 'auth-code')

      describe 'with a redirect URL', ->
        it 'matches the spec and includes the URL', ->
          url = 'http://redirect.to/here'
          expect(@oauth.accessTokenParams(url)).to.deep.equal(
              grant_type: 'authorization_code', code: 'auth-code',
              redirect_uri: url)

    describe '#authHeader', ->
      it 'uses HTTP Basic authentication with the id as the username', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Basic Y2xpZW50LWlkOmNsaWVudC1zZWNyZXQ=')

    describe '#addAuthParams', ->
      beforeEach ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the client id', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            client_id: 'client-id', client_secret: 'client-secret',
            answer: 42, other: 43)

    buildSecretTransitionTests()

  describe 'with an app key and Bearer token', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth key: 'client-id', token: 'access-token'

    describe '#credentials', ->
      it 'returns the app key and access token', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', token: 'access-token')

    describe '#step', ->
      it 'returns DONE', ->
        expect(@oauth.step()).to.equal Dropbox.Client.DONE

    describe '#authHeader', ->
      it 'uses HTTP Bearer auth', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Bearer access-token')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the access token', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            access_token: 'access-token', answer: 42, other: 43)

    buildSecretlessTransitionTests()

  describe 'with an app key + secret and Bearer token', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth(
        key: 'client-id', secret: 'client-secret', token: 'access-token')

    describe '#credentials', ->
      it 'returns the app key + secret and access token', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', secret: 'client-secret', token: 'access-token')

    describe '#step', ->
      it 'returns DONE', ->
        expect(@oauth.step()).to.equal Dropbox.Client.DONE

    describe '#authHeader', ->
      it 'uses HTTP Bearer auth', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Bearer access-token')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the access token', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            access_token: 'access-token', answer: 42, other: 43)

    buildSecretTransitionTests()

  describe 'with a Bearer token', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth token: 'access-token'

    describe '#credentials', ->
      it 'returns the access token', ->
        expect(@oauth.credentials()).to.deep.equal token: 'access-token'

    describe '#step', ->
      it 'returns DONE', ->
        expect(@oauth.step()).to.equal Dropbox.Client.DONE

    describe '#authHeader', ->
      it 'uses HTTP Bearer auth', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'Bearer access-token')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the access token', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            access_token: 'access-token', answer: 42, other: 43)

    buildKeylessTransitionTests()

  describe 'with an app key and MAC token', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth(
          key: 'client-id', token: 'access-token',
          tokenKey: 'token-key', tokenKid: 'token-kid')
      @stub = sinon.stub Dropbox.Util.Oauth, 'timestamp'
      @stub.returns @timestamp

    afterEach ->
      @stub.restore()

    describe '#credentials', ->
      it 'returns the app key and access token', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', token: 'access-token',
            tokenKey: 'token-key', tokenKid: 'token-kid')

    describe '#step', ->
      it 'returns DONE', ->
        expect(@oauth.step()).to.equal Dropbox.Client.DONE

    describe '#authHeader', ->
      it 'uses HTTP MAC auth', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'MAC kid=token-kid ts=1370129543574 access_token=access-token ' +
            'mac=tlkfjonwKYiWU0Yf5EYwyDQfpJs=')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the access token and signature', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            access_token: 'access-token', kid: 'token-kid',
            mac: 'tlkfjonwKYiWU0Yf5EYwyDQfpJs=', ts: 1370129543574,
            answer: 42, other: 43)

    buildSecretlessTransitionTests()

  describe 'with an app key + secret and MAC token', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth(
        key: 'client-id', secret: 'client-secret', token: 'access-token',
        tokenKey: 'token-key', tokenKid: 'token-kid')
      @stub = sinon.stub Dropbox.Util.Oauth, 'timestamp'
      @stub.returns @timestamp

    afterEach ->
      @stub.restore()

    describe '#credentials', ->
      it 'returns the app key + secret and access token', ->
        expect(@oauth.credentials()).to.deep.equal(
            key: 'client-id', secret: 'client-secret', token: 'access-token',
            tokenKey: 'token-key', tokenKid: 'token-kid')

    describe '#step', ->
      it 'returns DONE', ->
        expect(@oauth.step()).to.equal Dropbox.Client.DONE

    describe '#authHeader', ->
      it 'uses HTTP MAC auth', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'MAC kid=token-kid ts=1370129543574 access_token=access-token ' +
            'mac=tlkfjonwKYiWU0Yf5EYwyDQfpJs=')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the access token and signature', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            access_token: 'access-token', kid: 'token-kid',
            mac: 'tlkfjonwKYiWU0Yf5EYwyDQfpJs=', ts: 1370129543574,
            answer: 42, other: 43)

    buildSecretTransitionTests()

  describe 'with a MAC token', ->
    beforeEach ->
      @oauth = new Dropbox.Util.Oauth(
          token: 'access-token', tokenKey: 'token-key', tokenKid: 'token-kid')
      @stub = sinon.stub Dropbox.Util.Oauth, 'timestamp'
      @stub.returns @timestamp

    afterEach ->
      @stub.restore()

    describe '#credentials', ->
      it 'returns the app key and access token', ->
        expect(@oauth.credentials()).to.deep.equal(
            token: 'access-token', tokenKey: 'token-key',
            tokenKid: 'token-kid')

    describe '#step', ->
      it 'returns DONE', ->
        expect(@oauth.step()).to.equal Dropbox.Client.DONE

    describe '#authHeader', ->
      it 'uses HTTP MAC auth', ->
        expect(@oauth.authHeader(@method, @url, @params)).to.equal(
            'MAC kid=token-kid ts=1370129543574 access_token=access-token ' +
            'mac=tlkfjonwKYiWU0Yf5EYwyDQfpJs=')

    describe '#addAuthParams', ->
      it 'returns the given object', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.equal @params

      it 'adds the access token and signature', ->
        expect(@oauth.addAuthParams(@method, @url, @params)).to.deep.equal(
            access_token: 'access-token', kid: 'token-kid',
            mac: 'tlkfjonwKYiWU0Yf5EYwyDQfpJs=', ts: 1370129543574,
            answer: 42, other: 43)

    buildKeylessTransitionTests()

  describe '#queryParamsFromUrl', ->
    it 'extracts simple query params', ->
      url = 'http://localhost:8911/oauth_redirect?param1=value1&param2=value2'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          param1: 'value1', param2: 'value2')

    it 'extracts simple fragment params', ->
      url = 'http://localhost:8911/oauth_redirect#param1=value1&param2=value2'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          param1: 'value1', param2: 'value2')

    it 'extracts simple fragment query params', ->
      url = 'http://localhost:8911/oauth_redirect#?param1=value1&param2=value2'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          param1: 'value1', param2: 'value2')

    it 'extracts simple query and fragment params', ->
      url = 'http://localhost:8911/oauth_redirect?param1=value1#param2=value2'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          param1: 'value1', param2: 'value2')

    it 'extracts percent-encoded query params', ->
      url = 'http://localhost:8911/oauth_redirect?p%20=v%20'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          'p ': 'v ')

    it 'extracts query and fragment params with /-prefixed query', ->
      url = 'http://localhost:8911/oauth_redirect?/param1=value1#param2=value2'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          param1: 'value1', param2: 'value2')

    it 'extracts query and fragment params with /-prefixed fragment', ->
      url = 'http://localhost:8911/oauth_redirect?param1=value1#/param2=value2'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          param1: 'value1', param2: 'value2')

    it 'extracts /-prefixed fragment query param', ->
      url = 'http://localhost:8911/oauth_redirect#?/param1=value1'
      expect(Dropbox.Util.Oauth.queryParamsFromUrl(url)).to.deep.equal(
          param1: 'value1')

  describe '.timestamp', ->
    it 'returns a number', ->
      expect(Dropbox.Util.Oauth.timestamp()).to.be.a 'number'

    it 'returns non-decreasing values', ->
      ts = (Dropbox.Util.Oauth.timestamp() for i in [0..100])
      for i in [1..100]
        expect(ts[i - i]).to.be.lte(ts[i])

  describe '.randomAuthStateParam', ->
    it 'returns a short string', ->
      expect(Dropbox.Util.Oauth.randomAuthStateParam()).to.be.a 'string'
      expect(Dropbox.Util.Oauth.randomAuthStateParam().length).to.be.below 64

    it 'returns different values', ->
      values = (Dropbox.Util.Oauth.randomAuthStateParam() for i in [0..100])
      values.sort()
      for i in [1..100]
        expect(values[i - 1]).not.to.equal(values[i])
