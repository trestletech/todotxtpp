describe 'Dropbox.AuthDriver.BrowserBase', ->
  describe '#locationStateParam', ->
    beforeEach ->
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'currentLocation'
    afterEach ->
      @stub.restore()

    it 'returns null if the location does not contain the state', ->
      @stub.returns 'http://test/file#another_state=ab%20cd&stat=e'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal null

    it 'returns null if the fragment does not contain the state', ->
      @stub.returns 'http://test/file?state=decoy#another_state=ab%20cd&stat=e'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal null

    it "extracts the state when it is the first fragment param", ->
      @stub.returns 'http://test/file#state=ab%20cd&other_param=true'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal 'ab cd'

    it "extracts the state when it is the last fragment param", ->
      @stub.returns 'http://test/file#other_param=true&state=ab%20cd'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal 'ab cd'

    it "extracts the state when it is a middle fragment param", ->
      @stub.returns 'http://test/file#param1=true&state=ab%20cd&param2=true'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal 'ab cd'


describe 'Dropbox.AuthDriver.Redirect', ->
  describe '#url', ->
    beforeEach ->
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'currentLocation'

    afterEach ->
      @stub.restore()

    it 'defaults to the current location', ->
      @stub.returns 'http://test/file?a=true'
      driver = new Dropbox.AuthDriver.Redirect()
      expect(driver.url()).to.equal 'http://test/file?a=true'

    it 'removes the fragment from the location', ->
      @stub.returns 'http://test/file?a=true#deadfragment'
      driver = new Dropbox.AuthDriver.Redirect()
      expect(driver.url()).to.equal 'http://test/file?a=true'

    it 'removes tricky fragments from the location', ->
      @stub.returns 'http://test/file?a=true#/deadfragment'
      driver = new Dropbox.AuthDriver.Redirect()
      expect(driver.url()).to.equal 'http://test/file?a=true'

    it 'replaces the current file correctly', ->
      @stub.returns 'http://test:123/a/path/file?a=true#deadfragment'
      driver = new Dropbox.AuthDriver.Redirect redirectFile: 'another.file'
      expect(driver.url('oauth token')).to.equal(
          'http://test:123/a/path/another.file')

    it 'replaces the current file correctly in the presence of fragments', ->
      @stub.returns 'http://test:123/a/path/file?a=true#/deadfragment'
      driver = new Dropbox.AuthDriver.Redirect redirectFile: 'another.file'
      expect(driver.url('oauth token')).to.equal(
          'http://test:123/a/path/another.file')

    it 'replaces an entire URL without a query correctly', ->
      @stub.returns 'http://test/file?a=true'
      driver = new Dropbox.AuthDriver.Redirect(
          redirectUrl: 'https://something.com/filez')
      expect(driver.url('oauth token')).to.equal(
          'https://something.com/filez')

    it 'replaces an entire URL with a query correctly', ->
      @stub.returns 'http://test/file?a=true'
      driver = new Dropbox.AuthDriver.Redirect(
          redirectUrl: 'https://something.com/filez?query=param')
      expect(driver.url('oauth token')).to.equal(
          'https://something.com/filez?query=param')


describe 'Dropbox.AuthDriver.Popup', ->
  describe '#url', ->
    beforeEach ->
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'currentLocation'

    afterEach ->
      @stub.restore()

    it 'reflects the current page when there are no options', ->
      @stub.returns 'http://test:123/a/path/file.htmx'
      driver = new Dropbox.AuthDriver.Popup
      expect(driver.url('oauth token')).to.equal(
            'http://test:123/a/path/file.htmx')

    it 'replaces the current file correctly', ->
      @stub.returns 'http://test:123/a/path/file.htmx'
      driver = new Dropbox.AuthDriver.Popup receiverFile: 'another.file'
      expect(driver.url('oauth token')).to.equal(
          'http://test:123/a/path/another.file')

    it 'replaces the current file correctly in the presence of fragments', ->
      @stub.returns 'http://test:123/a/path/file.htmx#/deadfragment'
      driver = new Dropbox.AuthDriver.Popup receiverFile: 'another.file'
      expect(driver.url('oauth token')).to.equal(
          'http://test:123/a/path/another.file')

    it 'replaces the current file correctly in the presence of queries', ->
      @stub.returns 'http://test:123/a/path/file.htmx?p/aram=true'
      driver = new Dropbox.AuthDriver.Popup receiverFile: 'another.file'
      expect(driver.url('oauth token')).to.equal(
          'http://test:123/a/path/another.file')

    it 'replaces an entire URL without a query correctly', ->
      @stub.returns 'http://test:123/a/path/file.htmx'
      driver = new Dropbox.AuthDriver.Popup(
          receiverUrl: 'https://something.com/filez')
      expect(driver.url('oauth token')).to.equal(
          'https://something.com/filez')

    it 'replaces an entire URL with a query correctly', ->
      @stub.returns 'http://test:123/a/path/file.htmx'
      driver = new Dropbox.AuthDriver.Popup(
          receiverUrl: 'https://something.com/filez?query=param')
      expect(driver.url('oauth token')).to.equal(
          'https://something.com/filez?query=param')

  describe '#locationOrigin', ->
    testCases = [
      # http
      ['http://www.dropbox.com', 'http://www.dropbox.com'],
      ['http://www.dropbox.com/', 'http://www.dropbox.com'],
      ['http://www.dropbox.com/path', 'http://www.dropbox.com'],
      ['http://www.dropbox.com?query=true', 'http://www.dropbox.com'],
      ['http://www.dropbox.com#hash=true', 'http://www.dropbox.com'],
      ['http://www.dropbox.com/?query=true', 'http://www.dropbox.com'],
      ['http://www.dropbox.com/#hash', 'http://www.dropbox.com'],
      ['http://www.dropbox.com/path?query=true', 'http://www.dropbox.com'],
      ['http://www.dropbox.com/path#hash', 'http://www.dropbox.com'],
      ['https://www.dropbox.com/', 'https://www.dropbox.com'],
      ['http://www.dropbox.com:80', 'http://www.dropbox.com:80'],
      ['http://www.dropbox.com:80/', 'http://www.dropbox.com:80'],
      # file
      ['file://some_file', 'file://some_file'],
      ['file://path/to/file', 'file://path/to/file'],
      ['file://path/to/file?query=true', 'file://path/to/file'],
      ['file://path/to/file#fragment', 'file://path/to/file'],
    ]
    for testCase in testCases
      do (testCase) ->
        it "works for #{testCase[0]}", ->
          expect(Dropbox.AuthDriver.Popup.locationOrigin(testCase[0])).to.
              equal(testCase[1])
