describe 'Dropbox.ApiError', ->
  describe '.NETWORK_ERROR', ->
    beforeEach ->
      @code = Dropbox.ApiError.NETWORK_ERROR
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'NETWORK_ERROR'
    it 'is between 0 and 99', ->
      expect(@code).to.be.within 0, 99
    it 'is falsey', ->
      expect(@code).to.not.be.ok

  describe '.NO_CONTENT', ->
    beforeEach ->
      @code = Dropbox.ApiError.NO_CONTENT
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'NO_CONTENT'
    it 'is between 300 and 399', ->
      expect(@code).to.be.within 300, 399

  describe '.INVALID_PARAM', ->
    beforeEach ->
      @code = Dropbox.ApiError.INVALID_PARAM
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'INVALID_PARAM'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499
    it 'is less than INVALID_TOKEN', ->
      expect(@code).to.be.below Dropbox.ApiError.INVALID_TOKEN

  describe '.INVALID_TOKEN', ->
    beforeEach ->
      @code = Dropbox.ApiError.INVALID_TOKEN
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'INVALID_TOKEN'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499
    it 'is less than OAUTH_ERROR', ->
      expect(@code).to.be.below Dropbox.ApiError.OAUTH_ERROR

  describe '.OAUTH_ERROR', ->
    beforeEach ->
      @code = Dropbox.ApiError.OAUTH_ERROR
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'OAUTH_ERROR'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499
    it 'is less than NOT_FOUND', ->
      expect(@code).to.be.below Dropbox.ApiError.NOT_FOUND

  describe '.NOT_FOUND', ->
    beforeEach ->
      @code = Dropbox.ApiError.NOT_FOUND
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'NOT_FOUND'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499
    it 'is less than INVALID_METHOD', ->
      expect(@code).to.be.below Dropbox.ApiError.INVALID_METHOD

  describe '.INVALID_METHOD', ->
    beforeEach ->
      @code = Dropbox.ApiError.INVALID_METHOD
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'INVALID_METHOD'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499
    it 'is less than NOT_ACCEPTABLE', ->
      expect(@code).to.be.below Dropbox.ApiError.NOT_ACCEPTABLE

  describe '.NOT_ACCEPTABLE', ->
    beforeEach ->
      @code = Dropbox.ApiError.NOT_ACCEPTABLE
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'NOT_ACCEPTABLE'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499
    it 'is less than CONFLICT', ->
      expect(@code).to.be.below Dropbox.ApiError.CONFLICT

  describe '.CONFLICT', ->
    beforeEach ->
      @code = Dropbox.ApiError.CONFLICT
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'CONFLICT'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499
    it 'is less than RATE_LIMITED', ->
      expect(@code).to.be.below Dropbox.ApiError.RATE_LIMITED

  describe '.RATE_LIMITED', ->
    beforeEach ->
      @code = Dropbox.ApiError.RATE_LIMITED
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'RATE_LIMITED'
    it 'is between 400 and 499', ->
      expect(@code).to.be.within 400, 499

  describe '.SERVER_ERROR', ->
    beforeEach ->
      @code = Dropbox.ApiError.SERVER_ERROR
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'SERVER_ERROR'
    it 'is between 500 and 599', ->
      expect(@code).to.be.within 500, 599
    it 'is less than OVER_QUOTA', ->
      expect(@code).to.be.below Dropbox.ApiError.OVER_QUOTA

  describe '.OVER_QUOTA', ->
    beforeEach ->
      @code = Dropbox.ApiError.OVER_QUOTA
    it 'is defined', ->
      expect(Dropbox.ApiError).to.have.property 'OVER_QUOTA'
    it 'is between 500 and 599', ->
      expect(@code).to.be.within 500, 599
