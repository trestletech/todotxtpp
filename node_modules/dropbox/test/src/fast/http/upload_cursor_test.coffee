describe 'Dropbox.Http.UploadCursor', ->
  describe '.parse', ->
    describe 'on the API example', ->
      beforeEach ->
        cursorData = {
          "upload_id": "v0k84B0AT9fYkfMUp0sBTA",
          "offset": 31337,
          "expires": "Tue, 19 Jul 2011 21:55:38 +0000"
        }
        @cursor = Dropbox.Http.UploadCursor.parse cursorData

      it 'parses tag correctly', ->
        expect(@cursor).to.have.property 'tag'
        expect(@cursor.tag).to.equal 'v0k84B0AT9fYkfMUp0sBTA'

      it 'parses offset correctly', ->
        expect(@cursor).to.have.property 'offset'
        expect(@cursor.offset).to.equal 31337

      it 'parses expiresAt correctly', ->
        expect(@cursor).to.have.property 'expiresAt'
        expect(@cursor.expiresAt).to.be.instanceOf Date
        expect([
            'Tue, 19 Jul 2011 21:55:38 GMT',  # every sane JS platform
            'Tue, 19 Jul 2011 21:55:38 UTC'   # Internet Explorer
            ]).to.contain(@cursor.expiresAt.toUTCString())

      it 'round-trips through json / parse correctly', ->
        newCursor = Dropbox.Http.UploadCursor.parse @cursor.json()
        expect(newCursor).to.deep.equal @cursor

    describe 'on a reference string', ->
      beforeEach ->
        rawRef = 'v0k84B0AT9fYkfMUp0sBTA'
        @cursor = Dropbox.Http.UploadCursor.parse rawRef

      it 'parses tag correctly', ->
        expect(@cursor).to.have.property 'tag'
        expect(@cursor.tag).to.equal 'v0k84B0AT9fYkfMUp0sBTA'

      it 'parses offset correctly', ->
        expect(@cursor).to.have.property 'offset'
        expect(@cursor.offset).to.equal 0

      it 'parses expiresAt correctly', ->
        expect(@cursor).to.have.property 'expiresAt'
        expect(@cursor.expiresAt).to.be.instanceOf Date
        expect(@cursor.expiresAt - (new Date())).to.be.below 1000

      it 'round-trips through json / parse correctly', ->
        newCursor = Dropbox.Http.UploadCursor.parse @cursor.json()
        newCursor.json()  # Get _json populated for newCursor.
        expect(newCursor).to.deep.equal @cursor

    it 'passes null through', ->
      expect(Dropbox.Http.UploadCursor.parse(null)).to.equal null

    it 'passes undefined through', ->
      expect(Dropbox.Http.UploadCursor.parse(undefined)).to.equal undefined

  describe '.constructor', ->
    describe 'with no arguments', ->
      beforeEach ->
        @cursor = new Dropbox.Http.UploadCursor

      it 'sets up tag correctly', ->
        expect(@cursor).to.have.property 'tag'
        expect(@cursor.tag).to.equal null

      it 'parses offset correctly', ->
        expect(@cursor).to.have.property 'offset'
        expect(@cursor.offset).to.equal 0

      it 'parses expiresAt correctly', ->
        expect(@cursor).to.have.property 'expiresAt'
        expect(@cursor.expiresAt - (new Date())).to.be.below 1000

      it 'round-trips through json / parse correctly', ->
        newCursor = Dropbox.Http.UploadCursor.parse @cursor.json()
        newCursor.json()  # Get _json populated for newCursor.
        expect(newCursor).to.deep.equal @cursor

  describe '.replace', ->
    beforeEach ->
      @cursor = new Dropbox.Http.UploadCursor

    describe 'on the API example', ->
      beforeEach ->
        cursorData = {
          "upload_id": "v0k84B0AT9fYkfMUp0sBTA",
          "offset": 31337,
          "expires": "Tue, 19 Jul 2011 21:55:38 +0000"
        }
        @cursor.replace cursorData

      it 'parses tag correctly', ->
        expect(@cursor).to.have.property 'tag'
        expect(@cursor.tag).to.equal 'v0k84B0AT9fYkfMUp0sBTA'

      it 'parses offset correctly', ->
        expect(@cursor).to.have.property 'offset'
        expect(@cursor.offset).to.equal 31337

      it 'parses expiresAt correctly', ->
        expect(@cursor).to.have.property 'expiresAt'
        expect(@cursor.expiresAt).to.be.instanceOf Date
        expect([
            'Tue, 19 Jul 2011 21:55:38 GMT',  # every sane JS platform
            'Tue, 19 Jul 2011 21:55:38 UTC'   # Internet Explorer
            ]).to.contain(@cursor.expiresAt.toUTCString())

      it 'round-trips through json / parse correctly', ->
        newCursor = Dropbox.Http.UploadCursor.parse @cursor.json()
        expect(newCursor).to.deep.equal @cursor
