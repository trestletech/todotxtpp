describe 'Dropbox.Http.PollResult', ->
  describe '.parse', ->
    describe 'on a timeout', ->
      beforeEach ->
        response  = {"changes": false}
        @result = Dropbox.Http.PollResult.parse response

      it 'parses hasChanges correctly', ->
        expect(@result).to.have.property 'hasChanges'
        expect(@result.hasChanges).to.equal false

      it 'parses retryAfter correctly', ->
        expect(@result).to.have.property 'retryAfter'
        expect(@result.retryAfter).to.equal 0

    describe 'on a timeout with backoff', ->
      beforeEach ->
        response  = {"changes": false, "backoff": 5}
        @result = Dropbox.Http.PollResult.parse response

      it 'parses hasChanges correctly', ->
        expect(@result).to.have.property 'hasChanges'
        expect(@result.hasChanges).to.equal false

      it 'parses retryAfter correctly', ->
        expect(@result).to.have.property 'retryAfter'
        expect(@result.retryAfter).to.equal 5

    describe 'on a change report', ->
      beforeEach ->
        response  = {"changes": true}
        @result = Dropbox.Http.PollResult.parse response

      it 'parses hasChanges correctly', ->
        expect(@result).to.have.property 'hasChanges'
        expect(@result.hasChanges).to.equal true

      it 'parses retryAfter correctly', ->
        expect(@result).to.have.property 'retryAfter'
        expect(@result.retryAfter).to.equal 0

    it 'passes null through', ->
      expect(Dropbox.Http.PollResult.parse(null)).to.equal null

    it 'passes undefined through', ->
      expect(Dropbox.Http.PollResult.parse(undefined)).to.equal undefined
