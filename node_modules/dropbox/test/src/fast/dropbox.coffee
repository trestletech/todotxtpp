describe 'Dropbox', ->
  describe '#constructor', ->
    it 'throws an Error pointing people to Dropbox.Client', ->
      expect(-> new Dropbox()).to.throw Error, /Dropbox\.Client/
