describe 'Dropbox.AccountInfo', ->
  describe '.parse', ->
    describe 'on the API example', ->
      beforeEach ->
        userData = {
          "referral_link": "https://www.dropbox.com/referrals/r1a2n3d4m5s6t7",
          "display_name": "John P. User",
          "uid": 12345678,
          "country": "US",
          "quota_info": {
            "shared": 253738410565,
            "quota": 107374182400000,
            "normal": 680031877871
          },
          "email": "johnpuser@company.com"  # Added to reflect real responses.
        }
        @accountInfo = Dropbox.AccountInfo.parse userData

      it 'parses name correctly', ->
        expect(@accountInfo).to.have.property 'name'
        expect(@accountInfo.name).to.equal 'John P. User'

      it 'parses email correctly', ->
        expect(@accountInfo).to.have.property 'email'
        expect(@accountInfo.email).to.equal 'johnpuser@company.com'

      it 'parses countryCode correctly', ->
        expect(@accountInfo).to.have.property 'countryCode'
        expect(@accountInfo.countryCode).to.equal 'US'

      it 'parses uid correctly', ->
        expect(@accountInfo).to.have.property 'uid'
        expect(@accountInfo.uid).to.equal '12345678'

      it 'parses referralUrl correctly', ->
        expect(@accountInfo).to.have.property 'referralUrl'
        expect(@accountInfo.referralUrl).to.
            equal 'https://www.dropbox.com/referrals/r1a2n3d4m5s6t7'

      it 'parses quota correctly', ->
        expect(@accountInfo).to.have.property 'quota'
        expect(@accountInfo.quota).to.equal 107374182400000

      it 'parses usedQuota correctly', ->
        expect(@accountInfo).to.have.property 'usedQuota'
        expect(@accountInfo.usedQuota).to.equal 933770288436

      it 'parses privateBytes correctly', ->
        expect(@accountInfo).to.have.property 'privateBytes'
        expect(@accountInfo.privateBytes).to.equal 680031877871

      it 'parses sharedBytes correctly', ->
        expect(@accountInfo).to.have.property 'usedQuota'
        expect(@accountInfo.sharedBytes).to.equal 253738410565

      it 'parses publicAppUrl correctly', ->
        expect(@accountInfo.publicAppUrl).to.equal null

      it 'round-trips through json / parse correctly', ->
        newInfo = Dropbox.AccountInfo.parse @accountInfo.json()
        expect(newInfo).to.deep.equal @accountInfo

    it 'passes null through', ->
      expect(Dropbox.AccountInfo.parse(null)).to.equal null

    it 'passes undefined through', ->
      expect(Dropbox.AccountInfo.parse(undefined)).to.equal undefined


    describe 'on real data from a "public app folder" application', ->
      beforeEach ->
        userData = {
          "referral_link": "https://www.dropbox.com/referrals/NTM1OTg4MTA5",
          "display_name": "Victor Costan",
          "uid": 87654321,  # Anonymized.
          "public_app_url": "https://dl-web.dropbox.com/spa/90vw6zlu4268jh4/",
          "country": "US",
          "quota_info": {
            "shared": 6074393565,
            "quota": 73201090560,
            "normal": 4684642723
          },
          "email": "spam@gmail.com"  # Anonymized.
        }
        @accountInfo = Dropbox.AccountInfo.parse userData

      it 'parses publicAppUrl correctly', ->
        expect(@accountInfo.publicAppUrl).to.
          equal 'https://dl-web.dropbox.com/spa/90vw6zlu4268jh4'

      it 'round-trips through json / parse correctly', ->
        newInfo = Dropbox.AccountInfo.parse @accountInfo.json()
        expect(newInfo).to.deep.equal @accountInfo


