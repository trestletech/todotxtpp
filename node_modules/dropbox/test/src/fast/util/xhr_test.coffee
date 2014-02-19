describe 'Dropbox.Util.Xhr', ->
  beforeEach ->
    @oauth = new Dropbox.Util.Oauth(
      key: 'mock00key', secret: 'mock00secret', token: 'mock00token')

  describe 'with a GET', ->
    beforeEach ->
      @xhr = new Dropbox.Util.Xhr 'GET', 'https://request.url'

    it 'initializes correctly', ->
      expect(@xhr.isGet).to.equal true
      expect(@xhr.method).to.equal 'GET'
      expect(@xhr.url).to.equal 'https://request.url'
      expect(@xhr.preflight).to.equal false

    describe '#setHeader', ->
      beforeEach ->
        @xhr.setHeader 'Range', 'bytes=0-1000'

      it 'adds a HTTP header header', ->
        expect(@xhr.headers).to.have.property 'Range'
        expect(@xhr.headers['Range']).to.equal 'bytes=0-1000'

      it 'does not work twice for the same header', ->
        expect(=> @xhr.setHeader('Range', 'bytes=0-1000')).to.throw Error

      it 'flags the Xhr as needing preflight', ->
        expect(@xhr.preflight).to.equal true

      it 'rejects Content-Type', ->
        expect(=> @xhr.setHeader('Content-Type', 'text/plain')).to.throw Error

    describe '#setParams', ->
      beforeEach ->
        @xhr.setParams 'param 1': true, 'answer': 42

      it 'does not flag the XHR as needing preflight', ->
        expect(@xhr.preflight).to.equal false

      it 'does not work twice', ->
        expect(=> @xhr.setParams 'answer': 43).to.throw Error

      describe '#paramsToUrl', ->
        beforeEach ->
          @xhr.paramsToUrl()

        it 'changes the url', ->
          expect(@xhr.url).to.
              equal 'https://request.url?answer=42&param%201=true'

        it 'sets params to null', ->
          expect(@xhr.params).to.equal null

      describe '#paramsToBody', ->
        it 'throws an error', ->
          expect(=> @xhr.paramsToBody()).to.throw Error

      describe '#addOauthParams', ->
        beforeEach ->
          @xhr.addOauthParams @oauth

        it 'keeps existing params', ->
          expect(@xhr.params).to.have.property 'answer'
          expect(@xhr.params.answer).to.equal 42

        it 'adds an access_token param', ->
          expect(@xhr.params).to.have.property 'access_token'

        it 'does not add an Authorization header', ->
          expect(@xhr.headers).not.to.have.property 'Authorization'

        it 'does not work twice', ->
          expect(=> @xhr.addOauthParams()).to.throw Error

      describe '#addOauthHeader', ->
        beforeEach ->
          @xhr.addOauthHeader @oauth

        it 'keeps existing params', ->
          expect(@xhr.params).to.have.property 'answer'
          expect(@xhr.params.answer).to.equal 42

        it 'does not add an access_token param', ->
          expect(@xhr.params).not.to.have.property 'access_token'

        it 'adds an Authorization header', ->
          expect(@xhr.headers).to.have.property 'Authorization'

    describe '#addOauthParams without params', ->
      beforeEach ->
        @xhr.addOauthParams @oauth

      it 'adds an access_token param', ->
        expect(@xhr.params).to.have.property 'access_token'

    describe '#addOauthHeader without params', ->
      beforeEach ->
        @xhr.addOauthHeader @oauth

      it 'adds an Authorization header', ->
        expect(@xhr.headers).to.have.property 'Authorization'

    describe '#signWithOauth', ->
      describe 'for a request that does not need preflight', ->
        beforeEach ->
          @xhr.signWithOauth @oauth

        if Dropbox.Util.Xhr.doesPreflight
          it 'uses addOauthParams', ->
            expect(@xhr.params).to.have.property 'access_token'
        else
          it 'uses addOauthHeader in node.js', ->
            expect(@xhr.headers).to.have.property 'Authorization'

      describe 'for a request that needs preflight', ->
        beforeEach ->
          @xhr.setHeader 'Range', 'bytes=0-1000'
          @xhr.signWithOauth @oauth

        if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do HTTP headers.
          it 'uses addOauthParams in IE', ->
            expect(@xhr.params).to.have.property 'access_token'
        else
          it 'uses addOauthHeader', ->
            expect(@xhr.headers).to.have.property 'Authorization'

      describe 'with cacheFriendly: true', ->
        describe 'for a request that does not need preflight', ->
          beforeEach ->
            @xhr.signWithOauth @oauth, true

          if Dropbox.Util.Xhr.ieXdr
            it 'uses addOauthParams in IE', ->
              expect(@xhr.params).to.have.property 'access_token'
          else
            it 'uses addOauthHeader', ->
              expect(@xhr.headers).to.have.property 'Authorization'

        describe 'for a request that needs preflight', ->
          beforeEach ->
            @xhr.setHeader 'Range', 'bytes=0-1000'
            @xhr.signWithOauth @oauth, true

          if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do HTTP headers.
            it 'uses addOauthParams in IE', ->
              expect(@xhr.params).to.have.property 'access_token'
          else
            it 'uses addOauthHeader', ->
              expect(@xhr.headers).to.have.property 'Authorization'

    describe '#setFileField', ->
      it 'throws an error', ->
        expect(=> @xhr.setFileField('file', 'filename.bin', '<p>File Data</p>',
                                    'text/html')).to.throw Error

    describe '#setBody', ->
      it 'throws an error', ->
        expect(=> @xhr.setBody('body data')).to.throw Error

      it 'does not flag the XHR as needing preflight', ->
        expect(@xhr.preflight).to.equal false

    describe '#setResponseType', ->
      beforeEach ->
        @xhr.setResponseType 'b'

      it 'changes responseType', ->
        expect(@xhr.responseType).to.equal 'b'

      it 'does not flag the XHR as needing preflight', ->
        expect(@xhr.preflight).to.equal false

    describe '#prepare with params', ->
      beforeEach ->
        @xhr.setParams answer: 42
        @xhr.prepare()

      it 'creates the native xhr', ->
        expect(typeof @xhr.xhr).to.equal 'object'

      it 'opens the native xhr', ->
        return if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do readyState.
        expect(@xhr.xhr.readyState).to.equal 1

      it 'pushes the params in the url', ->
        expect(@xhr.url).to.equal 'https://request.url?answer=42'

  describe 'with a POST', ->
    beforeEach ->
      @xhr = new Dropbox.Util.Xhr 'POST', 'https://request.url'

    it 'initializes correctly', ->
      expect(@xhr.isGet).to.equal false
      expect(@xhr.method).to.equal 'POST'
      expect(@xhr.url).to.equal 'https://request.url'
      expect(@xhr.preflight).to.equal false

    describe '#setHeader', ->
      beforeEach ->
        @xhr.setHeader 'Range', 'bytes=0-1000'

      it 'adds a HTTP header header', ->
        expect(@xhr.headers).to.have.property 'Range'
        expect(@xhr.headers['Range']).to.equal 'bytes=0-1000'

      it 'does not work twice for the same header', ->
        expect(=> @xhr.setHeader('Range', 'bytes=0-1000')).to.throw Error

      it 'flags the Xhr as needing preflight', ->
        expect(@xhr.preflight).to.equal true

      it 'rejects Content-Type', ->
        expect(=> @xhr.setHeader('Content-Type', 'text/plain')).to.throw Error

    describe '#setParams', ->
      beforeEach ->
        @xhr.setParams 'param 1': true, 'answer': 42

      it 'does not work twice', ->
        expect(=> @xhr.setParams 'answer': 43).to.throw Error

      it 'does not flag the XHR as needing preflight', ->
        expect(@xhr.preflight).to.equal false

      describe '#paramsToUrl', ->
        beforeEach ->
          @xhr.paramsToUrl()

        it 'changes the url', ->
          expect(@xhr.url).to.
              equal 'https://request.url?answer=42&param%201=true'

        it 'sets params to null', ->
          expect(@xhr.params).to.equal null

        it 'does not set the body', ->
          expect(@xhr.body).to.equal null

      describe '#paramsToBody', ->
        beforeEach ->
          @xhr.paramsToBody()

        it 'url-encodes the params', ->
          expect(@xhr.body).to.equal 'answer=42&param%201=true'

        it 'sets the Content-Type header', ->
          expect(@xhr.headers).to.have.property 'Content-Type'
          expect(@xhr.headers['Content-Type']).to.
              equal 'application/x-www-form-urlencoded'

        it 'does not change the url', ->
          expect(@xhr.url).to.equal 'https://request.url'

        it 'does not work twice', ->
          @xhr.setParams answer: 43
          expect(=> @xhr.paramsToBody()).to.throw Error

      describe '#addOauthParams', ->
        beforeEach ->
          @xhr.addOauthParams @oauth

        it 'keeps existing params', ->
          expect(@xhr.params).to.have.property 'answer'
          expect(@xhr.params.answer).to.equal 42

        it 'adds an access_token param', ->
          expect(@xhr.params).to.have.property 'access_token'

        it 'does not add an Authorization header', ->
          expect(@xhr.headers).not.to.have.property 'Authorization'

        it 'does not work twice', ->
          expect(=> @xhr.addOauthParams()).to.throw Error

      describe '#addOauthHeader', ->
        beforeEach ->
          @xhr.addOauthHeader @oauth

        it 'keeps existing params', ->
          expect(@xhr.params).to.have.property 'answer'
          expect(@xhr.params.answer).to.equal 42

        it 'does not add an access_token param', ->
          expect(@xhr.params).not.to.have.property 'access_token'

        it 'adds an Authorization header', ->
          expect(@xhr.headers).to.have.property 'Authorization'

    describe '#addOauthParams without params', ->
      beforeEach ->
        @xhr.addOauthParams @oauth

      it 'adds an access_token param', ->
        expect(@xhr.params).to.have.property 'access_token'

    describe '#addOauthHeader without params', ->
      beforeEach ->
        @xhr.addOauthHeader @oauth

      it 'adds an Authorization header', ->
        expect(@xhr.headers).to.have.property 'Authorization'

    describe '#signWithOauth', ->
      describe 'for a request that does not need preflight', ->
        beforeEach ->
          @xhr.signWithOauth @oauth

        if Dropbox.Util.Xhr.doesPreflight
          it 'uses addOauthParams', ->
            expect(@xhr.params).to.have.property 'access_token'
        else
          it 'uses addOauthHeader in node.js', ->
            expect(@xhr.headers).to.have.property 'Authorization'

      describe 'for a request that needs preflight', ->
        beforeEach ->
          @xhr.setHeader 'Range', 'bytes=0-1000'
          @xhr.signWithOauth @oauth

        if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do HTTP headers.
          it 'uses addOauthParams in IE', ->
            expect(@xhr.params).to.have.property 'access_token'
        else
          it 'uses addOauthHeader', ->
            expect(@xhr.headers).to.have.property 'Authorization'

      describe 'with cacheFriendly: true', ->
        describe 'for a request that does not need preflight', ->
          beforeEach ->
            @xhr.signWithOauth @oauth, true

          if Dropbox.Util.Xhr.doesPreflight
            it 'uses addOauthParams', ->
              expect(@xhr.params).to.have.property 'access_token'
          else
            it 'uses addOauthHeader in node.js', ->
              expect(@xhr.headers).to.have.property 'Authorization'

        describe 'for a request that needs preflight', ->
          beforeEach ->
            @xhr.setHeader 'Range', 'bytes=0-1000'
            @xhr.signWithOauth @oauth, true

          if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do HTTP headers.
            it 'uses addOauthParams in IE', ->
              expect(@xhr.params).to.have.property 'access_token'
          else
            it 'uses addOauthHeader', ->
              expect(@xhr.headers).to.have.property 'Authorization'

    describe '#setFileField with a String', ->
      beforeEach ->
        @nonceStub = sinon.stub @xhr, 'multipartBoundary'
        @nonceStub.returns 'multipart----boundary'
        @xhr.setFileField 'file', 'filename.bin', '<p>File Data</p>',
                          'text/html'

      afterEach ->
        @nonceStub.restore()

      it 'sets the Content-Type header', ->
        expect(@xhr.headers).to.have.property 'Content-Type'
        expect(@xhr.headers['Content-Type']).to.
            equal 'multipart/form-data; boundary=multipart----boundary'

      it 'sets the body', ->
        expect(@xhr.body).to.equal("""--multipart----boundary\r
Content-Disposition: form-data; name="file"; filename="filename.bin"\r
Content-Type: text/html\r
Content-Transfer-Encoding: binary\r
\r
<p>File Data</p>\r
--multipart----boundary--\r\n
""")

      it 'does not work twice', ->
        expect(=> @xhr.setFileField('file', 'filename.bin', '<p>File Data</p>',
                                    'text/html')).to.throw Error

      it 'does not flag the XHR as needing preflight', ->
        expect(@xhr.preflight).to.equal false

    describe '#setBody with a string', ->
      beforeEach ->
        @xhr.setBody 'body data'

      it 'sets the request body', ->
        expect(@xhr.body).to.equal 'body data'

      it 'does not work twice', ->
        expect(=> @xhr.setBody('body data')).to.throw Error

      it 'does not flag the XHR as needing preflight', ->
        expect(@xhr.preflight).to.equal false

    describe '#setBody with FormData', ->
      beforeEach ->
        if FormData?
          formData = new FormData()
          formData.append 'name', 'value'
          @xhr.setBody formData

      it 'does not flag the XHR as needing preflight', ->
        return unless FormData?
        expect(@xhr.preflight).to.equal false

    describe '#setBody with Blob', ->
      beforeEach ->
        if Blob?
          try
            blob = new Blob ["abcdef"], type: 'image/png'
          catch blobError
            builder = new WebKitBlobBuilder
            builder.append "abcdef"
            blob = builder.getBlob 'image/png'

          @xhr.setBody blob

      it 'flags the XHR as needing preflight', ->
        return unless Blob?
        expect(@xhr.preflight).to.equal true

      it 'sets the Content-Type header', ->
        return unless Blob?
        expect(@xhr.headers).to.have.property 'Content-Type'
        expect(@xhr.headers['Content-Type']).to.
            equal 'application/octet-stream'

    describe '#setBody with ArrayBuffer', ->
      beforeEach ->
        if ArrayBuffer?
          buffer = new ArrayBuffer 5
          @xhr.setBody buffer

      it 'flags the XHR as needing preflight', ->
        return unless ArrayBuffer?
        expect(@xhr.preflight).to.equal true

      it 'sets the Content-Type header', ->
        return unless ArrayBuffer?
        expect(@xhr.headers).to.have.property 'Content-Type'
        expect(@xhr.headers['Content-Type']).to.
            equal 'application/octet-stream'

    describe '#setBody with ArrayBufferView', ->
      beforeEach ->
        if Uint8Array?
          view = new Uint8Array 5
          @xhr.setBody view

      it 'flags the XHR as needing preflight', ->
        return unless Uint8Array?
        expect(@xhr.preflight).to.equal true

      it 'sets the Content-Type header', ->
        return unless Uint8Array?
        expect(@xhr.headers).to.have.property 'Content-Type'
        expect(@xhr.headers['Content-Type']).to.
            equal 'application/octet-stream'

    describe '#setBody with node.js Buffer', ->
      beforeEach ->
        if Buffer?
          @xhr.setBody new Buffer(5)

      it 'flags the XHR as needing preflight', ->
        return unless Buffer?
        expect(@xhr.preflight).to.equal true

      it 'sets the Content-Type header', ->
        return unless Buffer?
        expect(@xhr.headers).to.have.property 'Content-Type'
        expect(@xhr.headers['Content-Type']).to.
            equal 'application/octet-stream'


    describe '#setResponseType', ->
      beforeEach ->
        @xhr.setResponseType 'b'

      it 'changes responseType', ->
        expect(@xhr.responseType).to.equal 'b'

      it 'does not flag the XHR as needing preflight', ->
        expect(@xhr.preflight).to.equal false

    describe '#prepare with params', ->
      beforeEach ->
        @xhr.setParams answer: 42
        @xhr.prepare()

      it 'creates the native xhr', ->
        expect(typeof @xhr.xhr).to.equal 'object'

      it 'opens the native xhr', ->
        return if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do readyState.
        expect(@xhr.xhr.readyState).to.equal 1

      if Dropbox.Util.Xhr.ieXdr
        it 'keeps the params in the URL in IE', ->
          expect(@xhr.url).to.equal 'https://request.url?answer=42'
          expect(@xhr.body).to.equal null
      else
        it 'pushes the params in the body', ->
          expect(@xhr.body).to.equal 'answer=42'

  describe 'with a PUT', ->
    beforeEach ->
      @xhr = new Dropbox.Util.Xhr 'PUT', 'https://request.url'

    it 'initializes correctly', ->
      expect(@xhr.isGet).to.equal false
      expect(@xhr.method).to.equal 'PUT'
      expect(@xhr.url).to.equal 'https://request.url'
      expect(@xhr.preflight).to.equal true

  describe '#urlEncode', ->
    it 'iterates properly', ->
      expect(Dropbox.Util.Xhr.urlEncode({foo: 'bar', baz: 5})).to.
        equal 'baz=5&foo=bar'
    it 'percent-encodes properly', ->
      expect(Dropbox.Util.Xhr.urlEncode({'a +x()': "*b'"})).to.
        equal 'a%20%2Bx%28%29=%2Ab%27'
    it 'does-not percent-encode characters singled out by OAuth spec', ->
      expect(Dropbox.Util.Xhr.urlEncode({'key': '1-2.3_4~'})).to.
        equal 'key=1-2.3_4~'

  describe '#urlDecode', ->
    it 'iterates properly', ->
      decoded = Dropbox.Util.Xhr.urlDecode('baz=5&foo=bar')
      expect(decoded['baz']).to.equal '5'
      expect(decoded['foo']).to.equal 'bar'
    it 'percent-decodes properly', ->
      decoded = Dropbox.Util.Xhr.urlDecode('a%20%2Bx%28%29=%2Ab%27')
      expect(decoded['a +x()']).to.equal "*b'"

  describe '#parseResponseHeaders', ->
    it 'parses one header correctly', ->
      headers = "Content-Type: 35225"
      decoded = Dropbox.Util.Xhr.parseResponseHeaders headers
      expect(decoded).to.deep.equal 'content-type': '35225'

    it 'parses multiple headers correctly', ->
      headers =
          """
          Content-Type: 35225
           s : t
          diffic ULT: Random: value: with: colons
          """
      decoded = Dropbox.Util.Xhr.parseResponseHeaders headers
      expect(decoded).to.deep.equal(
          'content-type': '35225', 's': 't',
          'diffic ult': 'Random: value: with: colons')

  describe '#send', ->
    beforeEach ->
      # The mock server doesn't have proper SSL certificates, so SSL
      # verification would fail.
      @node_js = module? and module?.exports? and require?
      if @node_js
        @XMLHttpRequest = require 'xhr2'
        @oldAgent = @XMLHttpRequest.nodejsHttpsAgent
        https = require 'https'
        agent = new https.Agent
        agent.options.rejectUnauthorized = false
        @XMLHttpRequest.nodejsSet httpsAgent: agent

      # The XHR test server isn't available for packaged apps.
      @cordova = cordova?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)

    afterEach ->
      if @node_js
        @XMLHttpRequest.nodejsSet httpsAgent: @oldAgent

    it 'processes form-urlencoded data correctly', (done) ->
      return done() if @cordova
      url = testXhrServer + '/form_encoded'
      xhr = new Dropbox.Util.Xhr 'POST', url
      xhr.prepare().send (error, data) ->
        expect(error).to.not.be.ok
        expect(data).to.have.property 'access_token'
        expect(data.access_token).to.equal 'test token'
        expect(data).to.have.property 'token_type'
        expect(data.token_type).to.equal 'Bearer'
        done()

    it 'processes form-urlencoded+charset data correctly', (done) ->
      return done() if @cordova
      url = testXhrServer + '/form_encoded?charset=utf8'
      xhr = new Dropbox.Util.Xhr 'POST', url
      xhr.prepare().send (error, data) ->
        expect(error).to.not.be.ok
        expect(data).to.have.property 'access_token'
        expect(data.access_token).to.equal 'test token'
        done()

    it 'processes JSON-encoded data correctly', (done) ->
      return done() if @cordova
      url = testXhrServer + '/json_encoded'
      xhr = new Dropbox.Util.Xhr 'POST', url
      xhr.prepare().send (error, data) ->
        expect(error).to.not.be.ok
        expect(data).to.have.property 'uid'
        expect(data.uid).to.equal 42
        expect(data).to.have.property 'country'
        expect(data.country).to.equal 'US'
        expect(data).to.have.property 'display_name'
        expect(data.display_name).to.equal 'John P. User'
        done()

    it 'processes JSON-encoded+charset data correctly', (done) ->
      return done() if @cordova
      url = testXhrServer + '/json_encoded?charset=utf8'
      xhr = new Dropbox.Util.Xhr 'POST', url
      xhr.prepare().send (error, data) ->
        expect(error).to.not.be.ok
        expect(data).to.have.property 'uid'
        expect(data.uid).to.equal 42
        done()

    it 'processes data correctly when using setCallback', (done) ->
      return done() if @cordova
      url = testXhrServer + '/form_encoded'
      xhr = new Dropbox.Util.Xhr 'POST', url
      xhr.setCallback (error, data) ->
        expect(error).to.not.be.ok
        expect(data).to.have.property 'access_token'
        expect(data.access_token).to.equal 'test token'
        expect(data).to.have.property 'token_type'
        expect(data.token_type).to.equal 'Bearer'
        done()
      xhr.prepare().send()

    it 'processes data and headers correctly', (done) ->
      return done() if @cordova
      url = testXhrServer + '/form_encoded'
      xhr = new Dropbox.Util.Xhr 'POST', url
      xhr.reportResponseHeaders()
      xhr.prepare().send (error, data, metadata, headers) ->
        expect(error).to.not.be.ok
        expect(data).to.have.property 'access_token'
        expect(data.access_token).to.equal 'test token'
        expect(data).to.have.property 'token_type'
        expect(data.token_type).to.equal 'Bearer'
        expect(headers).to.have.property 'content-type'
        expect(headers['content-type']).to.
            equal 'application/x-www-form-urlencoded'
        done()

    describe 'with a binary response', ->
      beforeEach ->
        @xhr = new Dropbox.Util.Xhr 'GET',
                                    testXhrServer + '/test/binary/dropbox.png'

      describe 'with responseType b', ->
        beforeEach ->
          @xhr.setResponseType 'b'

        it 'retrieves a string where each character is a byte', (done) ->
          return done() if @cordova
          @xhr.prepare().send (error, data) ->
            expect(error).to.not.be.ok
            expect(data).to.be.a 'string'
            bytes = (data.charCodeAt i for i in [0...data.length])
            expect(bytes).to.deep.equal testImageBytes
            done()

      describe 'with responseType arraybuffer', ->
        beforeEach ->
          @xhr.setResponseType 'arraybuffer'

        it 'retrieves a well-formed ArrayBuffer', (done) ->
          return done() if @cordova

          # Skip this test on IE 9 and below
          return done() unless ArrayBuffer?

          @xhr.prepare().send (error, buffer) ->
            expect(error).to.not.be.ok
            expect(buffer).to.be.instanceOf ArrayBuffer
            view = new Uint8Array buffer
            bytes = (view[i] for i in [0...buffer.byteLength])
            expect(bytes).to.deep.equal testImageBytes
            done()

      describe 'with responseType blob', ->
        beforeEach ->
          @xhr.setResponseType 'blob'

        it 'retrieves a well-formed Blob', (done) ->
          return done() if @cordova

          # Skip this test on node.js and IE 9 and below
          return done() unless Blob?

          @xhr.prepare().send (error, blob) ->
            expect(error).to.not.be.ok
            expect(blob).to.be.instanceOf Blob
            onBufferAvailable = (buffer) ->
              view = new Uint8Array buffer
              bytes = (view[i] for i in [0...buffer.byteLength])
              expect(bytes).to.deep.equal testImageBytes
              done()
            if typeof FileReaderSync isnt 'undefined'
              # Firefox WebWorkers don't have FileReader.
              reader = new FileReaderSync
              buffer = reader.readAsArrayBuffer blob
              onBufferAvailable buffer
            else
              reader = new FileReader
              reader.onloadend = ->
                return unless reader.readyState == FileReader.DONE
                onBufferAvailable reader.result
              reader.readAsArrayBuffer blob

      describe 'with responseType buffer', ->
        beforeEach ->
          if Buffer?
            @xhr.setResponseType 'buffer'

        it 'retrieves a well-formed Buffer on node.js', (done) ->
          return done() unless Buffer?

          @xhr.prepare().send (error, buffer) ->
            expect(error).to.not.be.ok
            expect(buffer).to.be.instanceOf Buffer
            bytes = (buffer.readUInt8(i) for i in [0...buffer.length])
            expect(bytes).to.deep.equal testImageBytes
            done()

    it 'sends Authorization headers correctly', (done) ->
      return done() if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't set headers.
      return done() if @cordova

      xhr = new Dropbox.Util.Xhr 'GET', testXhrServer + '/dropbox_file'
      xhr.addOauthHeader @oauth
      xhr.prepare().send (error, data) =>
        expect(error).to.equal null
        expect(data).to.equal 'Test file contents'

        xhr = new Dropbox.Util.Xhr 'GET', testXhrServer + '/dropbox_file'
        @oauth.setCredentials token: 'wrong00token'
        xhr.addOauthHeader @oauth
        xhr.prepare().send (error, data) ->
          expect(data).not.to.be.ok
          expect(error).to.be.instanceOf Dropbox.ApiError
          done()

    it 'parses X-Dropbox-Metadata correctly', (done) ->
      return done() if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't set headers.
      return done() if @cordova

      xhr = new Dropbox.Util.Xhr 'GET', testXhrServer + '/dropbox_file'
      xhr.addOauthHeader @oauth
      xhr.prepare().send (error, data, metadata) =>
        expect(error).to.equal null
        expect(data).to.equal 'Test file contents'
        expect(metadata).to.have.property 'size'
        expect(metadata.size).to.equal '1KB'
        expect(metadata).to.have.property 'is_dir'
        expect(metadata.is_dir).to.equal false
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal '/test_path.txt'
        done()

    it "doesn't crash on unparseable X-Dropbox-Metadata", (done) ->
      return done() if @cordova
      xhr = new Dropbox.Util.Xhr 'GET', testXhrServer + '/dropbox_file_bug/txt'
      xhr.prepare().send (error, data, metadata) =>
        expect(error).to.equal null
        expect(data).to.equal 'Test file contents'
        expect(metadata).not.to.be.ok
        done()

    it 'parses doubled X-Dropbox-Metadata header', (done) ->
      return done() if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't set headers.
      return done() if @cordova
      xhr = new Dropbox.Util.Xhr 'GET', testXhrServer + '/dropbox_file_bug/2x'
      xhr.prepare().send (error, data, metadata) =>
        expect(error).to.equal null
        expect(data).to.equal 'Test file contents'
        expect(metadata).to.have.property 'size'
        expect(metadata.size).to.equal '1KB'
        expect(metadata).to.have.property 'is_dir'
        expect(metadata.is_dir).to.equal false
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal '/test_path.txt'
        done()

    it 'reports errors correctly', (done) ->
      return done() if @cordova
      url = testXhrServer + '/dropbox_file'
      xhr = new Dropbox.Util.Xhr 'GET', url
      xhr.prepare().send (error, data) =>
        expect(data).to.equal undefined
        expect(error).to.be.instanceOf Dropbox.ApiError
        expect(error).to.have.property 'url'
        expect(error.url).to.equal url
        expect(error).to.have.property 'method'
        expect(error.method).to.equal 'GET'
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do HTTP status codes.
          expect(error).to.have.property 'status'
          expect(error.status).to.equal Dropbox.ApiError.INVALID_TOKEN
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR hides the HTTP body on error.
          expect(error).to.have.property 'responseText'
          expect(error.responseText).to.be.a 'string'
          expect(error.responseText).to.equal(
              '{"error":"invalid access token"}')
          expect(error).to.have.property 'response'
          expect(error.response).to.have.property 'error'
          expect(error.response.error).to.equal 'invalid access token'
        expect(error.toString()).to.match /^Dropbox API error/
        expect(error.toString()).to.contain 'GET'
        expect(error.toString()).to.contain url
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR hides the HTTP body on error.
          expect(error.toString()).to.contain 'invalid access token'
        done()

    it 'reports errors correctly when onError is set', (done) ->
      return done() if @cordova
      url = testXhrServer + '/dropbox_file'
      xhr = new Dropbox.Util.Xhr 'GET', url
      listenerError = null
      xhrCallbackCalled = false
      xhr.onError = (error, callback) ->
        expect(listenerError).to.equal null
        expect(xhrCallbackCalled).to.equal false
        listenerError = error
        callback error
      xhr.prepare().send (error, data) =>
        xhrCallbackCalled = true
        expect(data).to.equal undefined
        expect(error).to.be.instanceOf Dropbox.ApiError
        expect(error).to.have.property 'url'
        expect(error.url).to.equal url
        expect(error).to.have.property 'method'
        expect(error.method).to.equal 'GET'
        expect(listenerError).to.equal error
        done()

    it 'reports network errors correctly', (done) ->
      url = 'https://broken.to.causeanetworkerror.com/1/oauth/request_token'
      xhr = new Dropbox.Util.Xhr 'POST', url
      xhr.prepare().send (error, data) =>
        expect(data).to.equal undefined
        expect(error).to.be.instanceOf Dropbox.ApiError
        expect(error).to.have.property 'url'
        expect(error.url).to.equal url
        expect(error).to.have.property 'method'
        expect(error.method).to.equal 'POST'
        expect(error).to.have.property 'responseText'
        expect(error.responseText).to.equal '(no response)'
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do HTTP status codes.
          expect(error).to.have.property 'status'
          expect(error.status).to.equal Dropbox.ApiError.NETWORK_ERROR
        done()

