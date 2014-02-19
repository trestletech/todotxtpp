buildBlob = (fragments, mimeType) ->
  try
    return new Blob fragments, mimeType
  catch blobError
    builder = new WebKitBlobBuilder
    builder.append fragment for fragment in fragments
    return builder.getBlob mimeType

buildClientTests = (clientKeys) ->
  # Creates the global client.
  setupClient = (test, done) ->
    # Should only be used for fixture teardown.
    test.__client = new Dropbox.Client clientKeys
    done()

  # Creates the test directory.
  setupDirectory = (test, done) ->
    # True if running on node.js
    test.node_js = module? and module?.exports? and require?

    # All test data should go here.
    test.testFolder = '/js tests.' + Math.random().toString(36)
    test.__client.mkdir test.testFolder, (error, stat) ->
      expect(error).to.equal null
      done()

  # Creates the binary image file in the test directory.
  setupImageFile = (test, done) ->
    test.imageFile = "#{test.testFolder}/test-binary-image.png"
    test.imageFileBytes = testImageBytes

    setupImageFileUsingArrayBuffer test, (success) ->
      if success
        return done()
      setupImageFileUsingBlob test, (success) ->
        if success
          return done()
        setupImageFileUsingString test, done

  # Standard-compliant browsers write via XHR#send(ArrayBufferView).
  setupImageFileUsingArrayBuffer = (test, done) ->
    if Uint8Array?
      view = new Uint8Array test.imageFileBytes.length
      for i in [0...test.imageFileBytes.length]
        view[i] = test.imageFileBytes[i]
      buffer = view.buffer
      test.__client.writeFile test.imageFile, buffer, (error, stat) ->
        if error
          return done(false)
        # Some browsers will send the '[object Uint8Array]' string instead of
        # the ArrayBufferView.
        if stat.size is buffer.byteLength
          test.imageFileTag = stat.versionTag
          done true
        else
          done false
    else
      done false

  # Fallback to XHR#send(Blob).
  setupImageFileUsingBlob = (test, done) ->
    if Blob?
      view = new Uint8Array test.imageFileBytes.length
      for i in [0...test.imageFileBytes.length]
        view[i] = test.imageFileBytes[i]
      buffer = view.buffer
      blob = buildBlob [buffer], type: 'image/png'
      test.__client.writeFile test.imageFile, blob, (error, stat) ->
        if error
          return done(false)
        if stat.size is blob.size
          test.imageFileTag = stat.versionTag
          done true
        else
          done false
    else
      done false

  # Last resort: send a string that will get crushed by encoding errors.
  setupImageFileUsingString = (test, done) ->
    stringChars = for i in [0...test.imageFileBytes.length]
      String.fromCharCode(test.imageFileBytes[i])
    test.__client.writeFile(test.imageFile, stringChars.join(''),
        { binary: true },
        (error, stat) ->
          expect(error).to.equal null
          test.imageFileTag = stat.versionTag
          done()
        )

  # Creates the plaintext file in the test directory.
  setupTextFile = (test, done) ->
    test.textFile = "#{test.testFolder}/test-file.txt"
    test.textFileData = "Plaintext test file #{Math.random().toString(36)}.\n"
    test.__client.writeFile(test.textFile, test.textFileData,
        (error, stat) ->
          expect(error).to.equal null
          test.textFileTag = stat.versionTag
          done()
        )

  # Global (expensive) fixtures.
  before (done) ->
    setupClient @, =>
      setupDirectory @, =>
        setupImageFile @, =>
          setupTextFile @, ->
            done()

  # Teardown for global fixtures.
  after (done) ->
    @__client.remove @testFolder, (error, stat) =>
      throw new Error(error) if error
      done()

  # Per-test (cheap) fixtures.
  beforeEach ->
    @client = new Dropbox.Client clientKeys

  describe '#getAccountInfo', ->
    it 'returns reasonable information', (done) ->
      @client.getAccountInfo (error, accountInfo, rawAccountInfo) ->
        expect(error).to.equal null
        expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
        expect(accountInfo.uid).to.equal clientKeys.uid
        expect(rawAccountInfo).not.to.be.instanceOf Dropbox.AccountInfo
        expect(rawAccountInfo).to.have.property 'uid'
        done()

    describe 'with httpCache', ->
      beforeEach ->
        @xhr = null
        @client.onXhr.addListener (xhr) =>
          @xhr = xhr

      it 'uses Authorization headers', (done) ->
        @client.getAccountInfo httpCache: true,
            (error, accountInfo, rawAccountInfo) =>
              if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers
                expect(@xhr.url).to.contain 'access_token'
              else
                expect(@xhr.headers).to.have.key 'Authorization'

              expect(error).to.equal null
              expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
              expect(accountInfo.uid).to.equal clientKeys.uid
              expect(rawAccountInfo).not.to.be.instanceOf Dropbox.AccountInfo
              expect(rawAccountInfo).to.have.property 'uid'
              done()

  describe '#mkdir', ->
    afterEach (done) ->
      return done() unless @newFolder
      @client.remove @newFolder, (error, stat) -> done()

    it 'creates a folder in the test folder', (done) ->
      @newFolder = "#{@testFolder}/test'folder"
      @client.mkdir @newFolder, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFolder
        expect(stat.isFolder).to.equal true
        @client.stat @newFolder, (error, stat) =>
          expect(error).to.equal null
          expect(stat.isFolder).to.equal true
          done()

  describe '#readFile', ->
    beforeEach ->
      @newFile = null
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'reads a text file', (done) ->
      @client.readFile @textFile, (error, data, stat) =>
        expect(error).to.equal null
        expect(data).to.equal @textFileData
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat

          # TODO(pwnall): enable after API contents server bug is fixed
          #if clientKeys.key is testFullDropboxKeys.key
          #  expect(stat.inAppFolder).to.equal false
          #else
          #  expect(stat.inAppFolder).to.equal true
          expect(stat.path).to.equal @textFile
          expect(stat.isFile).to.equal true
        done()

    it 'reads the beginning of a text file', (done) ->
      return done() if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.

      @client.readFile @textFile, start: 0, length: 10,
          (error, data, stat, rangeInfo) =>
            expect(error).to.equal null
            expect(data).to.equal @textFileData.substring(0, 10)
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @textFile
            expect(stat.isFile).to.equal true
            expect(rangeInfo).to.be.instanceOf Dropbox.Http.RangeInfo
            expect(rangeInfo.start).to.equal 0
            expect(rangeInfo.end).to.equal 9
            expect(rangeInfo.size).to.equal @textFileData.length
            done()

    it 'reads the middle of a text file', (done) ->
      return done() if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.

      @client.readFile @textFile, start: 8, length: 10,
          (error, data, stat, rangeInfo) =>
            expect(error).to.equal null
            expect(data).to.equal @textFileData.substring(8, 18)
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @textFile
            expect(stat.isFile).to.equal true
            expect(rangeInfo).to.be.instanceOf Dropbox.Http.RangeInfo
            expect(rangeInfo.start).to.equal 8
            expect(rangeInfo.end).to.equal 17
            expect(rangeInfo.size).to.equal @textFileData.length
            done()

    it 'reads the end of a text file via the start: option', (done) ->
      return done() if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.

      @client.readFile @textFile, start: 10, (error, data, stat, rangeInfo) =>
        expect(error).to.equal null
        expect(data).to.equal @textFileData.substring(10)
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @textFile
        expect(stat.isFile).to.equal true
        expect(rangeInfo).to.be.instanceOf Dropbox.Http.RangeInfo
        expect(rangeInfo.start).to.equal 10
        expect(rangeInfo.end).to.equal @textFileData.length - 1
        expect(rangeInfo.size).to.equal @textFileData.length
        done()

    it 'reads the end of a text file via the length: option', (done) ->
      return done() if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.

      @client.readFile @textFile, length: 10, (error, data, stat, rangeInfo) =>
        expect(error).to.equal null
        expect(data).to.
            equal @textFileData.substring(@textFileData.length - 10)
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @textFile
        expect(stat.isFile).to.equal true
        expect(rangeInfo).to.be.instanceOf Dropbox.Http.RangeInfo
        expect(rangeInfo.start).to.equal @textFileData.length - 10
        expect(rangeInfo.end).to.equal @textFileData.length - 1
        expect(rangeInfo.size).to.equal @textFileData.length
        done()

    it 'reads a binary file into a string', (done) ->
      @client.readFile @imageFile, binary: true, (error, data, stat) =>
        expect(error).to.equal null
        bytes = (data.charCodeAt i for i in [0...data.length])
        expect(bytes).to.deep.equal @imageFileBytes
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        done()

    it 'reads a JSON file into a string', (done) ->
      jsonString = '{"answer":42,"autoParse":false}'
      @newFile = "#{@testFolder}/json test file.json"
      @client.writeFile @newFile, jsonString, (error, stat) =>
        expect(error).to.equal null
        @client.readFile @newFile, (error, data, stat) =>
          expect(error).to.equal null
          expect(data).to.equal jsonString
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
          done()

    it 'reads a binary file into a Blob', (done) ->
      return done() unless Blob?
      @client.readFile @imageFile, blob: true, (error, blob, stat) =>
        expect(error).to.equal null
        expect(blob).to.be.instanceOf Blob
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
          onBufferAvailable = (buffer) =>
            view = new Uint8Array buffer
            bytes = (view[i] for i in [0...buffer.byteLength])
            expect(bytes).to.deep.equal @imageFileBytes
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

    it 'reads a binary file into an ArrayBuffer', (done) ->
      return done() unless ArrayBuffer?
      @client.readFile @imageFile, arrayBuffer: true, (error, buffer, stat) =>
        expect(error).to.equal null
        expect(buffer).to.be.instanceOf ArrayBuffer
        expect(buffer.byteLength).to.equal @imageFileBytes.length
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        view = new Uint8Array buffer
        bytes = (view[i] for i in [0...buffer.byteLength])
        expect(bytes).to.deep.equal @imageFileBytes
        done()

    it 'reads a binary file into a node.js Buffer', (done) ->
      return done() unless Buffer?
      @client.readFile @imageFile, buffer: true, (error, buffer, stat) =>
        expect(error).to.equal null
        expect(buffer).to.be.instanceOf Buffer
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @imageFile
        expect(stat.isFile).to.equal true
        bytes = (buffer.readUInt8(i) for i in [0...buffer.length])
        expect(bytes).to.deep.equal @imageFileBytes
        done()

    it 'reports non-existing files correctly', (done) ->
      @client.readFile @textFile + '-not-found', (error, text, stat) =>
        expect(text).not.to.be.ok
        expect(stat).not.to.be.ok
        expect(error).to.be.instanceOf Dropbox.ApiError
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do error codes.
          expect(error.status).to.equal Dropbox.ApiError.NOT_FOUND
          expect(error.url).to.contain '-not-found'
        done()

    describe 'with an onXhr listener', ->
      beforeEach ->
        @listenerXhr = null
        @callbackCalled = false

      it 'calls the listener with a Dropbox.Util.Xhr argument', (done) ->
        @client.onXhr.addListener (xhr) =>
          expect(xhr).to.be.instanceOf Dropbox.Util.Xhr
          @listenerXhr = xhr
          true

        @client.readFile @textFile, (error, data, stat) =>
          expect(error).to.equal null
          expect(data).to.equal @textFileData
          done()

      it 'calls the listener before firing the XHR', (done) ->
        @client.onXhr.addListener (xhr) =>
          unless Dropbox.Util.Xhr.ieXdr  # IE's XHR doesn't have readyState
            expect(xhr.xhr.readyState).to.equal 1
          expect(@callbackCalled).to.equal false
          @listenerXhr = xhr
          true

        @client.readFile @textFile, (error, data, stat) =>
          @callbackCalled = true
          expect(@listenerXhr).to.be.instanceOf Dropbox.Util.Xhr
          expect(error).to.equal null
          expect(data).to.equal @textFileData
          done()

      it 'does not send the XHR if the listener cancels the event', (done) ->
        @client.onXhr.addListener (xhr) =>
          expect(@callbackCalled).to.equal false
          @listenerXhr = xhr
          # NOTE: if the client calls send(), a DOM error will fail the test
          xhr.send()
          false

        @client.readFile @textFile, (error, data, stat) =>
          @callbackCalled = true
          expect(@listenerXhr).to.be.instanceOf Dropbox.Util.Xhr
          done()

    describe 'with httpCache', ->
      beforeEach ->
        @xhr = null
        @client.onXhr.addListener (xhr) =>
          @xhr = xhr

      it 'reads a text file using Authorization headers', (done) ->
        @client.readFile @textFile, httpCache: true, (error, data, stat) =>
          if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers
            expect(@xhr.url).to.contain 'access_token'
          else
            expect(@xhr.headers).to.have.key 'Authorization'

          expect(error).to.equal null
          expect(data).to.equal @textFileData
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @textFile
            expect(stat.isFile).to.equal true
          done()

  describe '#writeFile', ->
    beforeEach ->
      @newFile = null
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'writes a new text file', (done) ->
      @newFile = "#{@testFolder}/another text file.txt"
      @newFileData = "Another plaintext file #{Math.random().toString(36)}."
      @client.writeFile @newFile, @newFileData, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        # TODO(pwnall): enable after API contents server bug is fixed
        #if clientKeys.key is testFullDropboxKeys.key
        #  expect(stat.inAppFolder).to.equal false
        #else
        #  expect(stat.inAppFolder).to.equal true
        @client.readFile @newFile, (error, data, stat) =>
          expect(error).to.equal null
          expect(data).to.equal @newFileData
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
          done()

    it 'writes a new empty file', (done) ->
      @newFile = "#{@testFolder}/another text file.txt"
      @newFileData = ''
      @client.writeFile @newFile, @newFileData, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        @client.readFile @newFile, (error, data, stat) =>
          expect(error).to.equal null
          expect(data).to.equal @newFileData
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
          done()

    it 'writes a new text file with ~ - and _ in the name', (done) ->
      @newFile = "#{@testFolder}/oauth~sig-test_file.txt"
      @newFileData = "A file whose name checks for OAuth signatures on ~-_"
      @client.writeFile @newFile, @newFileData, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        @client.readFile @newFile, (error, data, stat) =>
          expect(error).to.equal null
          expect(data).to.equal @newFileData
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
          done()

    it 'writes a Blob to a binary file', (done) ->
      return done() unless Blob? and ArrayBuffer?
      @newFile = "#{@testFolder}/test image from blob.png"
      newBuffer = new ArrayBuffer @imageFileBytes.length
      newBytes = new Uint8Array newBuffer
      for i in [0...@imageFileBytes.length]
        newBytes[i] = @imageFileBytes[i]
      @newBlob = buildBlob [newBytes], type: 'image/png'
      if @newBlob.size isnt newBuffer.byteLength
        @newBlob = buildBlob [newBuffer], type: 'image/png'
      @client.writeFile @newFile, @newBlob, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        expect(stat.size).to.equal @newBlob.size

        @client.readFile @newFile, arrayBuffer: true,
            (error, buffer, stat) =>
              expect(error).to.equal null
              expect(buffer).to.be.instanceOf ArrayBuffer
              expect(stat).to.be.instanceOf Dropbox.File.Stat
              expect(stat.path).to.equal @newFile
              expect(stat.isFile).to.equal true
              view = new Uint8Array buffer
              bytes = (view[i] for i in [0...buffer.byteLength])
              expect(bytes).to.deep.equal @imageFileBytes
              done()

    it 'writes a File to a binary file', (done) ->
      return done() unless File? and Blob? and ArrayBuffer?
      @newFile = "#{@testFolder}/test image from file.png"
      newBuffer = new ArrayBuffer @imageFileBytes.length
      newBytes = new Uint8Array newBuffer
      for i in [0...@imageFileBytes.length]
        newBytes[i] = @imageFileBytes[i]
      newBlob = buildBlob [newBytes], type: 'image/png'

      # Called when we have a File wrapping newBlob.
      actualTestCase = (file) =>
        @newFileObject = file
        @client.writeFile @newFile, @newFileObject, (error, stat) =>
          expect(error).to.equal null
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @newFile
          expect(stat.isFile).to.equal true
          expect(stat.size).to.equal @newFileObject.size

          @client.readFile @newFile, arrayBuffer: true,
              (error, buffer, stat) =>
                expect(error).to.equal null
                expect(buffer).to.be.instanceOf ArrayBuffer
                expect(stat).to.be.instanceOf Dropbox.File.Stat
                expect(stat.path).to.equal @newFile
                expect(stat.isFile).to.equal true
                view = new Uint8Array buffer
                bytes = (view[i] for i in [0...buffer.byteLength])
                expect(bytes).to.deep.equal @imageFileBytes
                done()

      # TODO(pwnall): use lighter method of constructing a File, when available
      #               http://crbug.com/164933
      return done() if typeof webkitRequestFileSystem is 'undefined'
      webkitRequestFileSystem window.TEMPORARY, 1024 * 1024, (fileSystem) ->
        # NOTE: the File name is different from the uploaded file name, to
        #       catch bugs such as http://crbug.com/165095
        fileSystem.root.getFile 'test image file.png',
            create: true, exclusive: false, (fileEntry) ->
              fileEntry.createWriter (fileWriter) ->
                fileWriter.onwriteend = ->
                  fileEntry.file (file) ->
                    actualTestCase file
                fileWriter.write newBlob

    it 'writes an ArrayBuffer to a binary file', (done) ->
      return done() unless ArrayBuffer?
      @newFile = "#{@testFolder}/test image from arraybuffer.png"
      @newBuffer = new ArrayBuffer @imageFileBytes.length
      newBytes = new Uint8Array @newBuffer
      for i in [0...@imageFileBytes.length]
        newBytes[i] = @imageFileBytes[i]
      @client.writeFile @newFile, @newBuffer, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        expect(stat.size).to.equal @newBuffer.byteLength

        @client.readFile @newFile, arrayBuffer: true,
            (error, buffer, stat) =>
              expect(error).to.equal null
              expect(buffer).to.be.instanceOf ArrayBuffer
              expect(stat).to.be.instanceOf Dropbox.File.Stat
              expect(stat.path).to.equal @newFile
              expect(stat.isFile).to.equal true
              view = new Uint8Array buffer
              bytes = (view[i] for i in [0...buffer.byteLength])
              expect(bytes).to.deep.equal @imageFileBytes
              done()

    it 'writes an ArrayBufferView to a binary file', (done) ->
      return done() unless ArrayBuffer?
      @newFile = "#{@testFolder}/test image from arraybufferview.png"
      @newBytes = new Uint8Array @imageFileBytes.length
      for i in [0...@imageFileBytes.length]
        @newBytes[i] = @imageFileBytes[i]
      @client.writeFile @newFile, @newBytes, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        expect(stat.size).to.equal @newBytes.byteLength

        @client.readFile @newFile, arrayBuffer: true,
            (error, buffer, stat) =>
              expect(error).to.equal null
              expect(buffer).to.be.instanceOf ArrayBuffer
              expect(stat).to.be.instanceOf Dropbox.File.Stat
              expect(stat.path).to.equal @newFile
              expect(stat.isFile).to.equal true
              view = new Uint8Array buffer
              bytes = (view[i] for i in [0...buffer.byteLength])
              expect(bytes).to.deep.equal @imageFileBytes
              done()

    it 'writes a node.js Buffer to a binary file', (done) ->
      return done() unless Buffer?
      @newFile = "#{@testFolder}/test image from node buffer.png"
      @newBuffer = new Buffer @imageFileBytes.length
      for i in [0...@imageFileBytes.length]
        @newBuffer.writeUInt8  @imageFileBytes[i], i
      @client.writeFile @newFile, @newBuffer, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        expect(stat.size).to.equal @newBuffer.length

        @client.readFile @newFile, buffer: true, (error, buffer, stat) =>
          expect(error).to.equal null
          expect(buffer).to.be.instanceOf Buffer
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @newFile
          expect(stat.isFile).to.equal true
          bytes = (buffer.readUInt8(i) for i in [0...buffer.length])
          expect(bytes).to.deep.equal @imageFileBytes
          done()

  describe '#resumableUploadStep + #resumableUploadFinish', ->
    beforeEach ->
      if ArrayBuffer?  # IE9 and below doesn't have ArrayBuffer
        @length1 = Math.ceil @imageFileBytes.length / 3
        @length2 = @imageFileBytes.length - @length1
        @arrayBuffer1 = new ArrayBuffer @length1
        @buffer1 = new Buffer @length1 if Buffer?

        @view1 = new Uint8Array @arrayBuffer1
        for i in [0...@length1]
          @view1[i] = @imageFileBytes[i]
          if @buffer1
            @buffer1.writeUInt8 @imageFileBytes[i], i
        @arrayBuffer2 = new ArrayBuffer @length2
        @buffer2 = new Buffer @length2 if Buffer?
        @view2 = new Uint8Array @arrayBuffer2
        for i in [0...@length2]
          @view2[i] = @imageFileBytes[@length1 + i]
          if @buffer2
            @buffer2.writeUInt8 @imageFileBytes[@length1 + i], i

        if Blob?  # node.js and IE9 and below don't have Blob
          @blob1 = buildBlob [@view1], type: 'image/png'
          if @blob1.size isnt @arrayBuffer1.byteLength
            @blob1 = buildBlob [@arrayBuffer1], type: 'image/png'
          @blob2 = buildBlob [@view2], type: 'image/png'
          if @blob2.size isnt @arrayBuffer2.byteLength
            @blob2 = buildBlob [@arrayBuffer2], type: 'image/png'

    afterEach (done) ->
      @timeout 30 * 1000  # This sequence is slow on the current API server.
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'writes a text file in two stages', (done) ->
      @timeout 20 * 1000  # This sequence is slow on the current API server.

      @newFile = "#{@testFolder}/test resumable upload.txt"
      line1 = "This is the first fragment\n"
      line2 = "This is the second fragment\n"
      @client.resumableUploadStep line1, null, (error, cursor1) =>
        expect(error).to.equal null
        expect(cursor1).to.be.instanceOf Dropbox.Http.UploadCursor
        expect(cursor1.offset).to.equal line1.length
        @client.resumableUploadStep line2, cursor1, (error, cursor2) =>
          expect(error).to.equal null
          expect(cursor2).to.be.instanceOf Dropbox.Http.UploadCursor
          expect(cursor2.offset).to.equal line1.length + line2.length
          expect(cursor2.tag).to.equal cursor1.tag
          @client.resumableUploadFinish @newFile, cursor2, (error, stat) =>
            expect(error).to.equal null
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
            # TODO(pwnall): enable after API contents server bug is fixed
            #if clientKeys.key is testFullDropboxKeys.key
            #  expect(stat.inAppFolder).to.equal false
            #else
            #  expect(stat.inAppFolder).to.equal true
            @client.readFile @newFile, (error, data, stat) =>
              expect(error).to.equal null
              expect(data).to.equal line1 + line2
              unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
                expect(stat).to.be.instanceOf Dropbox.File.Stat
                expect(stat.path).to.equal @newFile
                expect(stat.isFile).to.equal true
                # TODO(pwnall): enable after API contents server bug is fixed
                #if clientKeys.key is testFullDropboxKeys.key
                #  expect(stat.inAppFolder).to.equal false
                #else
                #  expect(stat.inAppFolder).to.equal true
              done()

    it 'writes a binary file using two ArrayBuffers', (done) ->
      return done() unless @arrayBuffer1
      @timeout 20 * 1000  # This sequence is slow on the current API server.

      @newFile = "#{@testFolder}/test resumable arraybuffer upload.png"
      @client.resumableUploadStep @arrayBuffer1, null, (error, cursor1) =>
        expect(error).to.equal null
        expect(cursor1).to.be.instanceOf Dropbox.Http.UploadCursor
        expect(cursor1.offset).to.equal @length1
        @client.resumableUploadStep @arrayBuffer2, cursor1, (error, cursor2) =>
          expect(error).to.equal null
          expect(cursor2).to.be.instanceOf Dropbox.Http.UploadCursor
          expect(cursor2.offset).to.equal @length1 + @length2
          expect(cursor2.tag).to.equal cursor1.tag
          @client.resumableUploadFinish @newFile, cursor2, (error, stat) =>
            expect(error).to.equal null
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
            @client.readFile @newFile, arrayBuffer: true,
                (error, buffer, stat) =>
                  expect(error).to.equal null
                  expect(buffer).to.be.instanceOf ArrayBuffer
                  expect(stat).to.be.instanceOf Dropbox.File.Stat
                  expect(stat.path).to.equal @newFile
                  expect(stat.isFile).to.equal true
                  view = new Uint8Array buffer
                  bytes = (view[i] for i in [0...buffer.byteLength])
                  expect(bytes).to.deep.equal @imageFileBytes
                  done()

    it 'writes a binary file using two ArrayBufferViews', (done) ->
      return done() unless @view1
      @timeout 20 * 1000  # This sequence is slow on the current API server.

      @newFile = "#{@testFolder}/test resumable arraybuffer upload.png"
      @client.resumableUploadStep @arrayBuffer1, null, (error, cursor1) =>
        expect(error).to.equal null
        expect(cursor1).to.be.instanceOf Dropbox.Http.UploadCursor
        expect(cursor1.offset).to.equal @length1
        @client.resumableUploadStep @arrayBuffer2, cursor1, (error, cursor2) =>
          expect(error).to.equal null
          expect(cursor2).to.be.instanceOf Dropbox.Http.UploadCursor
          expect(cursor2.offset).to.equal @length1 + @length2
          expect(cursor2.tag).to.equal cursor1.tag
          @client.resumableUploadFinish @newFile, cursor2, (error, stat) =>
            expect(error).to.equal null
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
            @client.readFile @newFile, arrayBuffer: true,
                (error, buffer, stat) =>
                  expect(error).to.equal null
                  expect(buffer).to.be.instanceOf ArrayBuffer
                  expect(stat).to.be.instanceOf Dropbox.File.Stat
                  expect(stat.path).to.equal @newFile
                  expect(stat.isFile).to.equal true
                  view = new Uint8Array buffer
                  bytes = (view[i] for i in [0...buffer.byteLength])
                  expect(bytes).to.deep.equal @imageFileBytes
                  done()

    it 'writes a binary file using two node.js Buffers', (done) ->
      return done() unless @buffer1
      @timeout 30 * 1000  # This sequence is slow on the current API server.

      @newFile = "#{@testFolder}/test resumable node buffer upload.png"
      @client.resumableUploadStep @buffer1, null, (error, cursor1) =>
        expect(error).to.equal null
        expect(cursor1).to.be.instanceOf Dropbox.Http.UploadCursor
        expect(cursor1.offset).to.equal @length1
        @client.resumableUploadStep @buffer2, cursor1, (error, cursor2) =>
          expect(error).to.equal null
          expect(cursor2).to.be.instanceOf Dropbox.Http.UploadCursor
          expect(cursor2.offset).to.equal @length1 + @length2
          expect(cursor2.tag).to.equal cursor1.tag
          @client.resumableUploadFinish @newFile, cursor2, (error, stat) =>
            expect(error).to.equal null
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
            @client.readFile @newFile, buffer: true,
                (error, buffer, stat) =>
                  expect(error).to.equal null
                  expect(buffer).to.be.instanceOf Buffer
                  expect(stat).to.be.instanceOf Dropbox.File.Stat
                  expect(stat.path).to.equal @newFile
                  expect(stat.isFile).to.equal true
                  bytes = (buffer.readUInt8(i) for i in [0...buffer.length])
                  expect(bytes).to.deep.equal @imageFileBytes
                  done()

    it 'writes a binary file using two Blobs', (done) ->
      return done() unless @blob1
      @timeout 20 * 1000  # This sequence is slow on the current API server.

      @newFile = "#{@testFolder}/test resumable blob upload.png"
      @client.resumableUploadStep @blob1, null, (error, cursor1) =>
        expect(error).to.equal null
        expect(cursor1).to.be.instanceOf Dropbox.Http.UploadCursor
        expect(cursor1.offset).to.equal @length1
        @client.resumableUploadStep @blob2, cursor1, (error, cursor2) =>
          expect(error).to.equal null
          expect(cursor2).to.be.instanceOf Dropbox.Http.UploadCursor
          expect(cursor2.offset).to.equal @length1 + @length2
          expect(cursor2.tag).to.equal cursor1.tag
          @client.resumableUploadFinish @newFile, cursor2, (error, stat) =>
            expect(error).to.equal null
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
            @client.readFile @newFile, arrayBuffer: true,
                (error, buffer, stat) =>
                  expect(error).to.equal null
                  expect(buffer).to.be.instanceOf ArrayBuffer
                  expect(stat).to.be.instanceOf Dropbox.File.Stat
                  expect(stat.path).to.equal @newFile
                  expect(stat.isFile).to.equal true
                  view = new Uint8Array buffer
                  bytes = (view[i] for i in [0...buffer.byteLength])
                  expect(bytes).to.deep.equal @imageFileBytes
                  done()

    it 'recovers from out-of-sync correctly', (done) ->
      # IE's XDR doesn't return anything on errors, so we can't do recovery.
      return done() if Dropbox.Util.Xhr.ieXdr
      @timeout 20 * 1000  # This sequence is slow on the current API server.

      @newFile = "#{@testFolder}/test resumable upload out of sync.txt"
      line1 = "This is the first fragment\n"
      line2 = "This is the second fragment\n"
      @client.resumableUploadStep line1, null, (error, cursor1) =>
        expect(error).to.equal null
        expect(cursor1).to.be.instanceOf Dropbox.Http.UploadCursor
        expect(cursor1.offset).to.equal line1.length
        cursor1.offset += 10
        @client.resumableUploadStep line2, cursor1, (error, cursor2) =>
          expect(error).to.equal null
          expect(cursor2).to.be.instanceOf Dropbox.Http.UploadCursor
          expect(cursor2.offset).to.equal line1.length
          expect(cursor2.tag).to.equal cursor1.tag
          @client.resumableUploadStep line2, cursor2, (error, cursor3) =>
            expect(error).to.equal null
            expect(cursor3).to.be.instanceOf Dropbox.Http.UploadCursor
            expect(cursor3.offset).to.equal line1.length + line2.length
            expect(cursor3.tag).to.equal cursor1.tag
            @client.resumableUploadFinish @newFile, cursor3, (error, stat) =>
              expect(error).to.equal null
              expect(stat).to.be.instanceOf Dropbox.File.Stat
              expect(stat.path).to.equal @newFile
              expect(stat.isFile).to.equal true
              @client.readFile @newFile, (error, data, stat) =>
                expect(error).to.equal null
                expect(data).to.equal line1 + line2
                unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
                  expect(stat).to.be.instanceOf Dropbox.File.Stat
                  expect(stat.path).to.equal @newFile
                  expect(stat.isFile).to.equal true
                done()

    it 'reports errors correctly', (done) ->
      @newFile = "#{@testFolder}/test resumable upload error.txt"
      badCursor = new Dropbox.Http.UploadCursor 'trollcursor'
      badCursor.offset = 42
      @client.resumableUploadStep @textFileData, badCursor, (error, cursor) =>
        expect(cursor).to.equal undefined
        expect(error).to.be.instanceOf Dropbox.ApiError
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do status codes.
          expect(error.status).to.equal Dropbox.ApiError.NOT_FOUND
        done()

  describe '#stat', ->
    it 'retrieves a Stat for a file', (done) ->
      @client.stat @textFile, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @textFile
        expect(stat.isFile).to.equal true
        expect(stat.versionTag).to.equal @textFileTag
        expect(stat.size).to.equal @textFileData.length
        if clientKeys.key is testFullDropboxKeys.key
          expect(stat.inAppFolder).to.equal false
        else
          expect(stat.inAppFolder).to.equal true
        done()

    it 'retrieves a Stat for a folder', (done) ->
      @client.stat @testFolder, (error, stat, entries) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @testFolder
        expect(stat.isFolder).to.equal true
        expect(stat.size).to.equal 0
        if clientKeys.key is testFullDropboxKeys.key
          expect(stat.inAppFolder).to.equal false
        else
          expect(stat.inAppFolder).to.equal true
        expect(entries).to.equal undefined
        done()

    it 'retrieves a Stat and entries for a folder', (done) ->
      @client.stat @testFolder, { readDir: true }, (error, stat, entries) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @testFolder
        expect(stat.isFolder).to.equal true
        expect(entries).to.be.ok
        expect(entries).to.have.length 2
        expect(entries[0]).to.be.instanceOf Dropbox.File.Stat
        expect(entries[0].path).not.to.equal @testFolder
        expect(entries[0].path).to.have.string @testFolder
        done()

    it 'fails cleanly for a non-existing path', (done) ->
      listenerError = null
      @client.onError.addListener (error) -> listenerError = error

      @client.stat @testFolder + '/should_404.txt', (error, stat, entries) =>
        expect(stat).to.equal undefined
        expect(entries).to.equal.null
        expect(error).to.be.instanceOf Dropbox.ApiError
        expect(listenerError).to.equal error
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do status codes.
          expect(error).to.have.property 'status'
          expect(error.status).to.equal Dropbox.ApiError.NOT_FOUND
        done()

    describe 'with httpCache', ->
      beforeEach ->
        @xhr = null
        @client.onXhr.addListener (xhr) =>
          @xhr = xhr

      it 'retrieves a Stat for a file using Authorization headers', (done) ->
        @client.stat @textFile, httpCache: true, (error, stat) =>
          if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers
            expect(@xhr.url).to.contain 'access_token'
          else
            expect(@xhr.headers).to.have.key 'Authorization'

          expect(error).to.equal null
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @textFile
          expect(stat.isFile).to.equal true
          expect(stat.versionTag).to.equal @textFileTag
          expect(stat.size).to.equal @textFileData.length
          if clientKeys.key is testFullDropboxKeys.key
            expect(stat.inAppFolder).to.equal false
          else
            expect(stat.inAppFolder).to.equal true
          done()

  describe '#readdir', ->
    it 'retrieves a Stat and entries for a folder', (done) ->
      @client.readdir @testFolder, (error, entries, dirStat, entryStats) =>
        expect(error).to.equal null
        expect(entries).to.be.ok
        expect(entries).to.have.length 2
        expect(entries[0]).to.be.a 'string'
        expect(entries[0]).not.to.have.string '/'
        expect(entries[0]).to.match /^(test-binary-image.png)|(test-file.txt)$/
        expect(dirStat).to.be.instanceOf Dropbox.File.Stat
        expect(dirStat.path).to.equal @testFolder
        expect(dirStat.isFolder).to.equal true
        if clientKeys.key is testFullDropboxKeys.key
          expect(dirStat.inAppFolder).to.equal false
        else
          expect(dirStat.inAppFolder).to.equal true
        expect(entryStats).to.be.ok
        expect(entryStats).to.have.length 2
        expect(entryStats[0]).to.be.instanceOf Dropbox.File.Stat
        expect(entryStats[0].path).not.to.equal @testFolder
        expect(entryStats[0].path).to.have.string @testFolder
        done()

    describe 'with httpCache', ->
      beforeEach ->
        @xhr = null
        @client.onXhr.addListener (xhr) =>
          @xhr = xhr

      it 'retrieves a folder Stat and entries using Authorization', (done) ->
        @client.readdir @testFolder, httpCache: true,
            (error, entries, dir_stat, entry_stats) =>
              if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers
                expect(@xhr.url).to.contain 'access_token'
              else
                expect(@xhr.headers).to.have.key 'Authorization'

              expect(error).to.equal null
              expect(entries).to.be.ok
              expect(entries).to.have.length 2
              expect(entries[0]).to.be.a 'string'
              expect(entries[0]).not.to.have.string '/'
              expect(entries[0]).to.match(
                  /^(test-binary-image.png)|(test-file.txt)$/)
              expect(dir_stat).to.be.instanceOf Dropbox.File.Stat
              expect(dir_stat.path).to.equal @testFolder
              expect(dir_stat.isFolder).to.equal true
              expect(entry_stats).to.be.ok
              expect(entry_stats).to.have.length 2
              expect(entry_stats[0]).to.be.instanceOf Dropbox.File.Stat
              expect(entry_stats[0].path).not.to.equal @testFolder
              expect(entry_stats[0].path).to.have.string @testFolder
              done()

    describe 'with contentHash', (done) ->
      beforeEach (done) ->
        @client.readdir @testFolder, (error, entries, dirStat) =>
          expect(error).to.equal null
          @contentHash = dirStat.contentHash
          done()

      it 'does not retrieve a folder twice if the tag matches', (done) ->
        @client.readdir @testFolder, contentHash: @contentHash,
            (error, entries) ->
              expect(error).to.be.instanceOf Dropbox.ApiError
              expect(entries).not.to.be.ok
              unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do status codes
                expect(error.status).to.equal Dropbox.ApiError.NO_CONTENT
              done()

  describe '#history', ->
    it 'gets a list of revisions', (done) ->
      @client.history @textFile, (error, versions) =>
        expect(error).to.equal null
        expect(versions).to.have.length 1
        expect(versions[0]).to.be.instanceOf Dropbox.File.Stat
        expect(versions[0].path).to.equal @textFile
        expect(versions[0].size).to.equal @textFileData.length
        expect(versions[0].versionTag).to.equal @textFileTag
        done()

    it 'returns 40x if the limit is set to 0', (done) ->
      listenerError = null
      @client.onError.addListener (error) -> listenerError = error

      @client.history @textFile, limit: 0, (error, versions) =>
        expect(error).to.be.instanceOf Dropbox.ApiError
        expect(listenerError).to.equal error
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do status codes.
          expect(error.status).to.be.within 400, 499
        expect(versions).not.to.be.ok
        done()

    describe 'with httpCache', ->
      beforeEach ->
        @xhr = null
        @client.onXhr.addListener (xhr) =>
          @xhr = xhr

      it 'gets a list of revisions using Authorization headers', (done) ->
        @client.history @textFile, httpCache: true, (error, versions) =>
          if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers
            expect(@xhr.url).to.contain 'access_token'
          else
            expect(@xhr.headers).to.have.key 'Authorization'

          expect(error).to.equal null
          expect(versions).to.have.length 1
          expect(versions[0]).to.be.instanceOf Dropbox.File.Stat
          expect(versions[0].path).to.equal @textFile
          expect(versions[0].size).to.equal @textFileData.length
          expect(versions[0].versionTag).to.equal @textFileTag
          done()

  describe '#copy', ->
    beforeEach ->
      @newFile = null
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'copies a file given by path', (done) ->
      @newFile = "#{@testFolder}/copy of test-file.txt"
      @client.copy @textFile, @newFile, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFile
        if clientKeys.key is testFullDropboxKeys.key
          expect(stat.inAppFolder).to.equal false
        else
          expect(stat.inAppFolder).to.equal true
        @client.readFile @newFile, (error, data, stat) =>
          expect(error).to.equal null
          expect(data).to.equal @textFileData
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
          @client.readFile @textFile, (error, data, stat) =>
            expect(error).to.equal null
            expect(data).to.equal @textFileData
            unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
              expect(stat).to.be.instanceOf Dropbox.File.Stat
              expect(stat.path).to.equal @textFile
              expect(stat.versionTag).to.equal @textFileTag
            done()

  describe '#makeCopyReference', ->
    beforeEach ->
      @newFile = null
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'creates a Dropbox.File.CopyReference that copies the file', (done) ->
      @newFile = "#{@testFolder}/ref copy of test-file.txt"

      @client.makeCopyReference @textFile, (error, copyRef) =>
        expect(error).to.equal null
        expect(copyRef).to.be.instanceOf Dropbox.File.CopyReference
        @client.copy copyRef, @newFile, (error, stat) =>
          expect(error).to.equal null
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @newFile
          expect(stat.isFile).to.equal true
          # TODO(pwnall): enable after API contents server bug is fixed
          # if clientKeys.key is testFullDropboxKeys.key
          #   expect(stat.inAppFolder).to.equal false
          # else
          #   expect(stat.inAppFolder).to.equal true
          @client.readFile @newFile, (error, data, stat) =>
            expect(error).to.equal null
            expect(data).to.equal @textFileData
            unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
              expect(stat).to.be.instanceOf Dropbox.File.Stat
              expect(stat.path).to.equal @newFile
            done()

  describe '#move', ->
    beforeEach (done) ->
      @moveFrom = "#{@testFolder}/move source of test-file.txt"
      @moveTo = null
      @client.copy @textFile, @moveFrom, (error, stat) ->
        expect(error).to.equal null
        done()

    afterEach (done) ->
      @client.remove @moveFrom, (error, stat) =>
        return done() unless @moveTo
        @client.remove @moveTo, (error, stat) -> done()

    it 'moves a file', (done) ->
      @moveTo = "#{@testFolder}/moved test-file.txt"
      @client.move @moveFrom, @moveTo, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @moveTo
        expect(stat.isFile).to.equal true
        if clientKeys.key is testFullDropboxKeys.key
          expect(stat.inAppFolder).to.equal false
        else
          expect(stat.inAppFolder).to.equal true
        @client.readFile @moveTo, (error, data, stat) =>
          expect(error).to.equal null
          expect(data).to.equal @textFileData
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @moveTo
          @client.readFile @moveFrom, (error, data, stat) ->
            expect(error).to.be.ok
            unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do status codes.
              expect(error).to.have.property 'status'
              expect(error.status).to.equal Dropbox.ApiError.NOT_FOUND
            expect(data).to.equal undefined
            unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
              expect(stat).to.equal undefined
            done()

  describe '#remove', ->
    beforeEach (done) ->
      @newFolder = "#{@testFolder}/folder delete test"
      @client.mkdir @newFolder, (error, stat) =>
        expect(error).to.equal null
        done()

    afterEach (done) ->
      return done() unless @newFolder
      @client.remove @newFolder, (error, stat) -> done()

    it 'deletes a folder', (done) ->
      @client.remove @newFolder, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFolder
        if clientKeys.key is testFullDropboxKeys.key
          expect(stat.inAppFolder).to.equal false
        else
          expect(stat.inAppFolder).to.equal true
        @client.stat @newFolder, { removed: true }, (error, stat) =>
          expect(error).to.equal null
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.isRemoved).to.equal true
          done()

    it 'deletes a folder when called as unlink', (done) ->
      @client.unlink @newFolder, (error, stat) =>
        expect(error).to.equal null
        expect(stat).to.be.instanceOf Dropbox.File.Stat
        expect(stat.path).to.equal @newFolder
        @client.stat @newFolder, { removed: true }, (error, stat) =>
          expect(error).to.equal null
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.isRemoved).to.equal true
          done()

  describe '#revertFile', ->
    describe 'on a removed file', ->
      beforeEach (done) ->
        @newFile = "#{@testFolder}/file revert test.txt"
        @client.copy @textFile, @newFile, (error, stat) =>
          expect(error).to.equal null
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @newFile
          @versionTag = stat.versionTag
          @client.remove @newFile, (error, stat) =>
            expect(error).to.equal null
            expect(stat).to.be.instanceOf Dropbox.File.Stat
            expect(stat.path).to.equal @newFile
            done()

      afterEach (done) ->
        return done() unless @newFile
        @client.remove @newFile, (error, stat) -> done()

      it 'reverts the file to a previous version', (done) ->
        @client.revertFile @newFile, @versionTag, (error, stat) =>
          expect(error).to.equal null
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @newFile
          expect(stat.isRemoved).to.equal false
          # TODO(pwnall): enable after API contents server bug is fixed
          #if clientKeys.key is testFullDropboxKeys.key
          #  expect(stat.inAppFolder).to.equal false
          #else
          #  expect(stat.inAppFolder).to.equal true
          @client.readFile @newFile, (error, data, stat) =>
            expect(error).to.equal null
            expect(data).to.equal @textFileData
            unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
              expect(stat).to.be.instanceOf Dropbox.File.Stat
              expect(stat.path).to.equal @newFile
              expect(stat.isRemoved).to.equal false
            done()

  describe '#findByName', ->
    it 'locates the test folder given a partial name', (done) ->
      namePattern = @testFolder.substring 5
      @client.search '/', namePattern, (error, matches) =>
        expect(error).to.equal null
        expect(matches).to.have.length 1
        expect(matches[0]).to.be.instanceOf Dropbox.File.Stat
        expect(matches[0].path).to.equal @testFolder
        expect(matches[0].isFolder).to.equal true
        # TODO(pwnall): enable after API contents server bug is fixed
        # if clientKeys.key is testFullDropboxKeys.key
        #   expect(matches[0].inAppFolder).to.equal false
        # else
        #   expect(matches[0].inAppFolder).to.equal true
        done()

    it 'lists the test folder files given the "test" pattern', (done) ->
      @client.search @testFolder, 'test', (error, matches) =>
        expect(error).to.equal null
        expect(matches).to.have.length 2
        done()

    it 'only lists one match when given limit 1', (done) ->
      @client.search @testFolder, 'test', limit: 1, (error, matches) =>
        expect(error).to.equal null
        expect(matches).to.have.length 1
        done()

    describe 'with httpCache', ->
      beforeEach ->
        @xhr = null
        @client.onXhr.addListener (xhr) =>
          @xhr = xhr

      it 'locates the test folder using Authorization headers', (done) ->
        namePattern = @testFolder.substring 5
        @client.search '/', namePattern, httpCache: true, (error, matches) =>
          if Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers
            expect(@xhr.url).to.contain 'access_token'
          else
            expect(@xhr.headers).to.have.key 'Authorization'

          expect(error).to.equal null
          expect(matches).to.have.length 1
          expect(matches[0]).to.be.instanceOf Dropbox.File.Stat
          expect(matches[0].path).to.equal @testFolder
          expect(matches[0].isFolder).to.equal true
          done()

  describe '#makeUrl', ->
    describe 'for a short Web URL', ->
      it 'returns a shortened Dropbox URL', (done) ->
        @client.makeUrl @textFile, (error, urlInfo) ->
          expect(error).to.equal null
          expect(urlInfo).to.be.instanceOf Dropbox.File.ShareUrl
          expect(urlInfo.isDirect).to.equal false
          expect(urlInfo.url).to.contain '//db.tt/'
          done()

      it 'returns a shortened Dropbox URL when given empty options', (done) ->
        @client.makeUrl @textFile, {}, (error, urlInfo) ->
          expect(error).to.equal null
          expect(urlInfo).to.be.instanceOf Dropbox.File.ShareUrl
          expect(urlInfo.isDirect).to.equal false
          expect(urlInfo.url).to.contain '//db.tt/'
          done()

    describe 'for a Web URL created with long: true', ->
      it 'returns an URL to a preview page', (done) ->
        @client.makeUrl @textFile, { long: true }, (error, urlInfo) =>
          expect(error).to.equal null
          expect(urlInfo).to.be.instanceOf Dropbox.File.ShareUrl
          expect(urlInfo.isDirect).to.equal false
          expect(urlInfo.url).not.to.contain '//db.tt/'

          # The preview server does not return CORS headers.
          return done() unless @node_js
          xhr = new Dropbox.Util.Xhr 'GET', urlInfo.url
          xhr.prepare().send (error, data) =>
            expect(error).to.equal null
            expect(data).to.contain '<!DOCTYPE html>'
            done()

    describe 'for a Web URL created with longUrl: true', ->
      it 'returns an URL to a preview page', (done) ->
        @client.makeUrl @textFile, { longUrl: true }, (error, urlInfo) =>
          expect(error).to.equal null
          expect(urlInfo).to.be.instanceOf Dropbox.File.ShareUrl
          expect(urlInfo.isDirect).to.equal false
          expect(urlInfo.url).not.to.contain '//db.tt/'
          done()

    describe 'for a direct download URL', ->
      it 'gets a direct download URL', (done) ->
        @client.makeUrl @textFile, { download: true }, (error, urlInfo) =>
          expect(error).to.equal null
          expect(urlInfo).to.be.instanceOf Dropbox.File.ShareUrl
          expect(urlInfo.isDirect).to.equal true
          expect(urlInfo.url).not.to.contain '//db.tt/'

          xhr = new Dropbox.Util.Xhr 'GET', urlInfo.url
          xhr.prepare().send (error, data) =>
            expect(error).to.equal null
            expect(data).to.equal @textFileData
            done()

    describe 'for a direct download URL created with downloadHack: true', ->
      it 'gets a direct long-lived download URL', (done) ->
        @client.makeUrl @textFile, { downloadHack: true }, (error, urlInfo) =>
          expect(error).to.equal null
          expect(urlInfo).to.be.instanceOf Dropbox.File.ShareUrl
          expect(urlInfo.isDirect).to.equal true
          expect(urlInfo.url).not.to.contain '//db.tt/'
          expect(urlInfo.expiresAt - Date.now()).to.be.above 86400000

          xhr = new Dropbox.Util.Xhr 'GET', urlInfo.url
          xhr.prepare().send (error, data) =>
            expect(error).to.equal null
            expect(data).to.equal @textFileData
            done()

  describe '#thumbnailUrl', ->
    it 'produces an URL that contains the file name', ->
      url = @client.thumbnailUrl @imageFile, { png: true, size: 'medium' }
      expect(url).to.contain 'tests'  # Fragment of the file name.
      expect(url).to.contain 'png'
      expect(url).to.contain 'medium'

  describe '#readThumbnail', ->
    it 'reads the image into a string', (done) ->
      @client.readThumbnail @imageFile, { png: true }, (error, data, stat) =>
        expect(error).to.equal null
        expect(data).to.be.a 'string'
        expect(data).to.contain 'PNG'
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @imageFile
          #expect(stat.isFile).to.equal true
          #if clientKeys.key is testFullDropboxKeys.key
          #  expect(stat.inAppFolder).to.equal false
          #else
          #  expect(stat.inAppFolder).to.equal true
        done()

    it 'reads the image into a Blob', (done) ->
      return done() unless Blob?
      options = { png: true, blob: true }
      @client.readThumbnail @imageFile, options, (error, blob, stat) =>
        expect(error).to.equal null
        expect(blob).to.be.instanceOf Blob
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        onBufferAvailable = (buffer) ->
          view = new Uint8Array buffer
          length = buffer.byteLength
          bytes = (String.fromCharCode view[i] for i in [0...length]).
              join('')
          expect(bytes).to.contain 'PNG'
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

    it 'reads the image into an ArrayBuffer', (done) ->
      return done() unless ArrayBuffer?
      options = { png: true, arrayBuffer: true }
      @client.readThumbnail @imageFile, options, (error, buffer, stat) =>
        expect(error).to.equal null
        expect(buffer).to.be.instanceOf ArrayBuffer
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        view = new Uint8Array buffer
        length = buffer.byteLength
        bytes = (String.fromCharCode view[i] for i in [0...length]).
            join('')
        expect(bytes).to.contain 'PNG'
        done()

    it 'reads the image into a node.js Buffer', (done) ->
      return done() unless Buffer?
      options = { png: true, buffer: true }
      @client.readThumbnail @imageFile, options, (error, buffer, stat) =>
        expect(error).to.equal null
        expect(buffer).to.be.instanceOf Buffer
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do headers.
          expect(stat).to.be.instanceOf Dropbox.File.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        length = buffer.length
        bytes =
            (String.fromCharCode buffer.readUInt8(i) for i in [0...length]).
            join('')
        expect(bytes).to.contain 'PNG'
        done()

  describe '#pullChanges', ->
    describe 'with valid args', ->
      beforeEach ->
        # /delta takes a long time, and we need an unbounded number of them.
        @timeoutValue = 60 * 1000
        @timeout @timeoutValue

      afterEach (done) ->
        @timeoutValue += 10 * 1000
        @timeout @timeoutValue
        return done() unless @newFile
        @client.remove @newFile, (error, stat) -> done()

      it 'gets a cursor, then it gets relevant changes', (done) ->
        @timeout @timeoutValue

        @client.pullChanges (error, changes) =>
          expect(error).to.equal null
          expect(changes).to.be.instanceOf Dropbox.Http.PulledChanges
          expect(changes.blankSlate).to.equal true

          # Calls pullChanges until it's done listing the user's Dropbox.
          drainEntries = (client, callback) =>
            return callback() unless changes.shouldPullAgain
            @timeoutValue += 10 * 1000  # 10 extra seconds per call
            @timeout @timeoutValue
            client.pullChanges changes, (error, _changes) ->
              expect(error).to.equal null
              changes = _changes
              drainEntries client, callback

          drainEntries @client, =>
            @newFile = "#{@testFolder}/delta-test.txt"
            newFileData = "This file is used to test pullChanges.\n"
            @client.writeFile @newFile, newFileData, (error, stat) =>
              expect(error).to.equal null
              expect(stat).to.have.property 'path'
              expect(stat.path).to.equal @newFile

              @client.pullChanges changes, (error, changes) =>
                expect(error).to.equal null
                expect(changes).to.be.instanceOf Dropbox.Http.PulledChanges
                expect(changes.blankSlate).to.equal false
                expect(changes.changes).to.have.length.greaterThan 0
                change = changes.changes[changes.changes.length - 1]
                expect(change).to.be.instanceOf Dropbox.Http.PulledChange
                expect(change.path).to.equal @newFile
                expect(change.wasRemoved).to.equal false
                expect(change.stat.path).to.equal @newFile
                done()

    describe 'with a bad cursor', ->
      it 'returns an error', (done) ->
        @client.pullChanges '[troll-cursor]', (error, changes) ->
          expect(changes).not.to.be.ok
          expect(error).to.be.instanceOf Dropbox.ApiError
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do status codes.
            expect(error).to.have.property 'status'
            expect(error.status).to.equal Dropbox.ApiError.INVALID_PARAM
            done()

  describe '#pollForChanges', ->
    describe 'with a valid cursor', ->
      beforeEach (done) ->
        # Pulling an entire Dropbox can take a lot of time, so we need fancy
        # logic here.
        @timeoutValue = 60 * 1000
        @timeout @timeoutValue

        @client.pullChanges (error, changes) =>
          expect(error).to.equal null
          expect(changes).to.be.instanceOf Dropbox.Http.PulledChanges

          # Calls pullChanges until it's done listing the user's Dropbox.
          drainEntries = (client, callback) =>
            return callback() unless changes.shouldPullAgain
            @timeoutValue += 10 * 1000  # 10 extra seconds per call
            @timeout @timeoutValue
            client.pullChanges changes, (error, _changes) ->
              expect(error).to.equal null
              changes = _changes
              drainEntries client, callback

          # Wait a few seconds for previous test operations to trickle down to
          # the notification servers.
          delayedDrainEntries = =>
            drainEntries @client, =>
              @changes = changes
              done()
          setTimeout delayedDrainEntries, 3000

      afterEach (done) ->
        @timeoutValue += 10 * 1000
        @timeout @timeoutValue
        return done() unless @newFile
        @client.remove @newFile, (error, stat) -> done()

      it 'gets notified when changes happen', (done) ->
        # TODO(pwnall): enable browser tests when api-notify gets CORS headers
        return done() unless @node_js

        @timeout @timeoutValue

        # A file that will be written after 3 seconds.
        @newFile = "#{@testFolder}/longpoll-delta-test.txt"
        newFileData = "This file is used to test pollForChanges.\n"
        fileWritten = false

        # The callback for this should be called after the file is written.
        @client.pollForChanges @changes, timeout: 30, (error, result) =>
          expect(error).to.equal null
          expect(result).to.be.instanceOf Dropbox.Http.PollResult
          expect(['hasChanges', result.hasChanges]).to.deep.equal(
              ['hasChanges', true])
          expect(['fileWritten', fileWritten]).to.deep.equal(
              ['fileWritten', true])

          @client.pullChanges @changes, (error, changes) =>
            expect(error).to.equal null
            expect(changes).to.be.instanceOf Dropbox.Http.PulledChanges
            expect(changes.blankSlate).to.equal false
            expect(changes.changes).to.have.length.greaterThan 0
            change = changes.changes[changes.changes.length - 1]
            expect(change).to.be.instanceOf Dropbox.Http.PulledChange
            expect(change.path).to.equal @newFile
            expect(change.wasRemoved).to.equal false
            expect(change.stat.path).to.equal @newFile
            done()

        # Called to write the change-triggering file after 3 seconds.
        writeFile = =>
          fileWritten = true
          @client.writeFile @newFile, newFileData, (error, stat) =>
            expect(error).to.equal null
            expect(stat).to.have.property 'path'
            expect(stat.path).to.equal @newFile
        setTimeout writeFile, 3000

    describe 'with an invalid cursor', ->
      it 'returns an error', (done) ->
        # TODO(pwnall): enable browser tests when api-notify gets CORS headers
        return done() unless @node_js

        @client.pollForChanges '[troll-cursor]', (error, changes) ->
          expect(changes).not.to.be.ok
          expect(error).to.be.instanceOf Dropbox.ApiError
          unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do status codes.
            expect(error).to.have.property 'status'
            expect(error.status).to.equal Dropbox.ApiError.INVALID_PARAM
            done()

  describe '#appInfo', ->
    it 'returns an error for non-existing app keys', (done) ->
      @client.appInfo 'no0such0key', (error, appInfo) ->
        expect(appInfo).not.to.be.ok
        expect(error).to.be.instanceOf Dropbox.ApiError
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't HTTP status codes.
          expect(error.status).to.equal Dropbox.ApiError.INVALID_PARAM
        done()

    it 'uses the client key if no key is given', (done) ->
      @client.appInfo (error, appInfo) ->
        expect(error).to.equal null
        expect(appInfo).to.be.instanceOf Dropbox.Http.AppInfo
        expect(appInfo.name).to.match /Automated Testing Keys/i
        expect(appInfo.key).to.equal clientKeys.key
        expect(appInfo.canUseDatastores).to.equal true
        expect(appInfo.canUseFiles).to.equal true
        if clientKeys.key is testFullDropboxKeys.key
          expect(appInfo.canUseFullDropbox).to.equal true
        else
          expect(appInfo.canUseFullDropbox).to.equal false
        expect(appInfo.icon(Dropbox.Http.AppInfo.ICON_SMALL)).to.be.a 'string'
        expect(appInfo.icon(Dropbox.Http.AppInfo.ICON_LARGE)).to.be.a 'string'
        done()

    it 'uses a key if given', (done) ->
      if clientKeys.key is testFullDropboxKeys.key
        otherKey = testKeys.key
        expectFullDropbox = false
      else
        otherKey = testFullDropboxKeys.key
        expectFullDropbox = true

      @client.appInfo otherKey, (error, appInfo) ->
        expect(error).to.equal null
        expect(appInfo).to.be.instanceOf Dropbox.Http.AppInfo
        expect(appInfo.name).to.match /Automated Testing Keys/i
        expect(appInfo.key).to.equal otherKey
        expect(appInfo.canUseFullDropbox).to.equal expectFullDropbox
        done()

    it 'returns valid PNG icons', (done) ->
      @client.appInfo (error, appInfo) ->
        expect(error).to.equal null
        expect(appInfo).to.be.instanceOf Dropbox.Http.AppInfo
        smallUrl = appInfo.icon Dropbox.Http.AppInfo.ICON_SMALL
        largeUrl = appInfo.icon Dropbox.Http.AppInfo.ICON_LARGE
        expect(smallUrl).to.be.a 'string'
        expect(largeUrl).to.be.a 'string'
        expect(smallUrl).not.to.equal largeUrl
        smallXhr = new Dropbox.Util.Xhr 'GET', smallUrl
        smallXhr.prepare().send (error, data) =>
          expect(error).to.equal null
          expect(data).to.contain 'PNG'
          largeXhr = new Dropbox.Util.Xhr 'GET', largeUrl
          largeXhr.prepare().send (error, data) =>
            expect(error).to.equal null
            expect(data).to.contain 'PNG'
            done()

  describe '#isAppDeveloper', ->
    it 'returns an error for non-existing app keys', (done) ->
      @client.isAppDeveloper 1, 'no0such0key', (error, isAppDeveloper) ->
        expect(isAppDeveloper).to.equal undefined
        expect(error).to.be.instanceOf Dropbox.ApiError
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't HTTP status codes.
          expect(error.status).to.equal Dropbox.ApiError.INVALID_PARAM
        done()

    it 'uses the client key if no key is given', (done) ->
      @client.isAppDeveloper 1, (error, isDeveloper) ->
        expect(error).to.equal null
        expect(isDeveloper).to.equal false
        done()

    it 'works with AppInfo instances', (done) ->
      @client.appInfo (error, appInfo) =>
        expect(error).to.equal null
        credentials = @client.credentials()
        delete credentials['key']
        client = new Dropbox.Client credentials
        client.isAppDeveloper 1, appInfo, (error, isDeveloper) ->
          expect(error).to.equal null
          expect(isDeveloper).to.equal false
          done()

  describe '#hasOauthRedirectUri', ->
    beforeEach ->
      @yesUri = 'https://www.dropbox.com/1/oauth2/redirect_receiver'
      @noUri = 'https://www.dropbox.com/not/really/registered'

    it 'returns an error for non-existing app keys', (done) ->
      @client.hasOauthRedirectUri @yesUri, 'no0such0key', (error, hasUri) ->
        expect(hasUri).to.equal undefined
        expect(error).to.be.instanceOf Dropbox.ApiError
        unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't HTTP status codes.
          expect(error.status).to.equal Dropbox.ApiError.INVALID_PARAM
        done()

    it 'uses the client key if no key is given', (done) ->
      @client.hasOauthRedirectUri @yesUri, (error, hasUri) ->
        expect(error).to.equal null
        expect(hasUri).to.equal true
        done()

    it 'reports missing URIs correctly', (done) ->
      @client.hasOauthRedirectUri @noUri, (error, hasUri) ->
        expect(error).to.equal null
        expect(hasUri).to.equal false
        done()

    it 'works with AppInfo instances', (done) ->
      @client.appInfo (error, appInfo) =>
        expect(error).to.equal null
        credentials = @client.credentials()
        delete credentials['key']
        client = new Dropbox.Client credentials
        client.hasOauthRedirectUri @noUri, appInfo, (error, hasUri) ->
          expect(error).to.equal null
          expect(hasUri).to.equal false
          done()

  describe '#appHash', ->
    it 'is consistent', ->
      client = new Dropbox.Client clientKeys
      expect(client.appHash()).to.equal @client.appHash()

    it 'is a non-trivial string', ->
      expect(@client.appHash()).to.be.a 'string'
      expect(@client.appHash().length).to.be.greaterThan 4

  describe '#isAuthenticated', ->
    it 'is true for a client with full tokens', ->
      expect(@client.isAuthenticated()).to.equal true

    it 'is false for a freshly reset client', ->
      @client.reset()
      expect(@client.isAuthenticated()).to.equal false

  describe '#authenticate', ->
    describe 'with interactive: false', ->
      beforeEach ->
        @driver =
          doAuthorize: ->
            assert false, 'The OAuth driver should not be invoked'
          url: ->
            'https://localhost:8912/oauth_redirect'
        @client.authDriver @driver

      it 'proceeds from AUTHORIZED with interactive: false', (done) ->
        @client.reset()
        credentials = @client.credentials()
        if '__secret' of clientKeys
          # Browser drivers use Implicit Grant, so they don't use the API
          # secret. However, this code path assumes on Authorization Code, so
          # it needs the API secret.
          credentials.secret = clientKeys.__secret
        credentials.oauthCode = 'invalid_authorization_code'
        @client.setCredentials credentials
        expect(@client.authStep).to.equal Dropbox.Client.AUTHORIZED
        @client.authenticate interactive: false, (error, client) ->
          expect(error).to.be.ok
          unless Dropbox.Util.Xhr.ieXdr
            expect(error).to.be.instanceOf Dropbox.AuthError
            expect(error).to.have.property 'code'
            expect(error.code).to.equal Dropbox.AuthError.INVALID_GRANT
            expect(error).to.have.property 'description'
            expect(error.description).to.
                match(/code.*not valid/i)
          done()

describe 'Dropbox.Client', ->
  # Skip some of the long tests in Web workers.
  unless (typeof self isnt 'undefined') and (typeof window is 'undefined')
    describe 'with full Dropbox access', ->
      buildClientTests testFullDropboxKeys

  describe 'with Folder access', ->
    buildClientTests testKeys

    describe '#authenticate + #signOut', ->
      # NOTE: we're not duplicating this test in the full Dropbox acess suite,
      #       because it's annoying to the tester
      it 'completes the authenticate flow', (done) ->
        if (typeof self isnt 'undefined') and (typeof window is 'undefined')
          return done()  # skip in Web workers

        @timeout 45 * 1000  # Time-consuming because the user must click.
        @client.reset()
        @client.authDriver authDriver
        authStepChanges = ['authorize']
        @client.onAuthStepChange.addListener (client) ->
          authStepChanges.push client.authStep
        @client.authenticate (error, client) =>
          expect(error).to.equal null
          expect(client).to.equal @client
          expect(client.authStep).to.equal Dropbox.Client.DONE
          expect(client.isAuthenticated()).to.equal true
          if testKeys.secret
            # node.js uses Authorization Codes
            expect(authStepChanges).to.deep.equal(['authorize',
                Dropbox.Client.PARAM_SET, Dropbox.Client.AUTHORIZED,
                Dropbox.Client.DONE])
          else
            # Browsers use Implicit Grant.
            expect(authStepChanges).to.deep.equal(['authorize',
                Dropbox.Client.PARAM_SET, Dropbox.Client.DONE])

          # Verify that we can do API calls.
          client.getAccountInfo (error, accountInfo) ->
            expect(error).to.equal null
            expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
            invalidCredentials = client.credentials()
            authStepChanges = ['signOut']
            client.signOut (error) ->
              expect(error).to.equal null
              expect(client.authStep).to.equal Dropbox.Client.SIGNED_OUT
              expect(client.isAuthenticated()).to.equal false
              expect(authStepChanges).to.deep.equal(['signOut',
                  Dropbox.Client.SIGNED_OUT])
              # Verify that we can't use the old token in API calls.
              # We have an invalid token, so we also test 401 handling.
              invalidClient = new Dropbox.Client invalidCredentials
              invalidClient.onAuthStepChange.addListener (client) ->
                authStepChanges.push client.authStep
              authStepChanges = ['invalidClient']
              invalidClient.authDriver onAuthStepChange: (client, callback) ->
                expect(authStepChanges).to.deep.equal(['invalidClient',
                    Dropbox.Client.ERROR])
                authStepChanges.push 'driver-' + client.authStep
                callback()
              invalidClient.onError.addListener (client) ->
                expect(authStepChanges).to.deep.equal(['invalidClient',
                    Dropbox.Client.ERROR, 'driver-' + Dropbox.Client.ERROR])
                authStepChanges.push 'onError'
              invalidClient.getAccountInfo (error, accountInfo) ->
                # TODO(pwnall): uncomment the lines below when we get OAuth 2
                #               token invalidation on the API server
                expect(error).to.be.ok
                unless Dropbox.Util.Xhr.ieXdr  # IE's XDR doesn't do HTTP codes.
                  expect(error.status).to.equal Dropbox.ApiError.INVALID_TOKEN
                  expect(invalidClient.authError).to.equal error
                  expect(invalidClient.isAuthenticated()).to.equal false
                  expect(authStepChanges).to.deep.equal(['invalidClient',
                      Dropbox.Client.ERROR, 'driver-' + Dropbox.Client.ERROR,
                      'onError'])

                # Verify that the same client can be used for a 2nd signin.
                authStepChanges = ['authorize2']
                client.authenticate (error, client) ->
                  expect(error).to.equal null
                  expect(client.authStep).to.equal Dropbox.Client.DONE
                  expect(client.isAuthenticated()).to.equal true
                  if testKeys.secret
                    # node.js uses Authorization Codes
                    expect(authStepChanges).to.deep.equal(['authorize2',
                        Dropbox.Client.PARAM_SET, Dropbox.Client.AUTHORIZED,
                        Dropbox.Client.DONE])
                  else
                    # Browsers use Implicit Grant.
                    expect(authStepChanges).to.deep.equal(['authorize2',
                        Dropbox.Client.PARAM_SET, Dropbox.Client.DONE])

                  # Verify that we can do API calls after the 2nd signin.
                  client.getAccountInfo (error, accountInfo) ->
                    expect(error).to.equal null
                    expect(accountInfo).to.be.instanceOf Dropbox.AccountInfo
                    done()

    describe '#appHash', ->
      it 'depends on the app key', ->
        client = new Dropbox.Client testFullDropboxKeys
        expect(client.appHash()).not.to.equal @client.appHash()

