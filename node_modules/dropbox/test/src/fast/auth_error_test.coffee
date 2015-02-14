describe 'Dropbox.AuthError', ->
  describe '#constructor', ->
    it 'throws an exception when given a non-error response', ->
      expect(=>new Dropbox.AuthError(
          access_token: 'token', token_type: 'Bearer')).to.throw(Error,
          /oauth.*error/i)

  describe 'with the RFC 6749 4.2.2 example', ->
    beforeEach ->
      @error = new Dropbox.AuthError error: 'access_denied', state: 'xyz'

    it 'parses the error code', ->
      expect(@error).to.have.property 'code'
      expect(@error.code).to.equal Dropbox.AuthError.ACCESS_DENIED

    it "doesn't report a description", ->
      expect(@error.description).to.equal null

    it "doesn't report an URI", ->
      expect(@error.uri).to.equal null

    describe '#toString', ->
      it 'reports the error code', ->
        expect(@error.toString()).to.match(/access_denied/i)

      it 'says it is related to OAuth', ->
        expect(@error.toString()).to.match(/oauth.*error/i)

  describe 'with a synthetic example', ->
    beforeEach ->
      @error = new Dropbox.AuthError(
          error: 'invalid_scope',
          error_description: 'The Dropbox API does not use scopes',
          error_uri: 'http://error.uri', state: 'xyz')

    it 'parses the error code', ->
      expect(@error).to.have.property 'code'
      expect(@error.code).to.equal Dropbox.AuthError.INVALID_SCOPE

    it 'parses the description', ->
      expect(@error.description).to.equal 'The Dropbox API does not use scopes'

    it 'parses the URI', ->
      expect(@error.uri).to.equal 'http://error.uri'

    describe '#toString', ->
      it 'reports the error code', ->
        expect(@error.toString()).to.match(/invalid_scope/i)

      it 'reports the error description', ->
        expect(@error.toString()).to.match(/not use scopes/i)

      it 'says it is related to OAuth', ->
        expect(@error.toString()).to.match(/oauth.*error/i)

  describe 'with an API server example', ->
    beforeEach ->
      @error = new Dropbox.AuthError(
          error: {
            error: 'invalid_grant',
            error_description: 'given "code" is not valid'
          })

    it 'parses the error code', ->
      expect(@error).to.have.property 'code'
      expect(@error.code).to.equal Dropbox.AuthError.INVALID_GRANT

    it 'parses the description', ->
      expect(@error.description).to.equal 'given "code" is not valid'
