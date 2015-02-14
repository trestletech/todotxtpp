describe 'Dropbox.Util.parseDate', ->
  it 'parses the date in the /shares API example', ->
    date = Dropbox.Util.parseDate 'Tue, 01 Jan 2030 00:00:00 +0000'
    expect(date).to.be.instanceOf Date
    expect(date.valueOf()).to.equal 1893456000000

  it 'parses the date in the /copy_ref API example', ->
    date = Dropbox.Util.parseDate 'Fri, 31 Jan 2042 21:01:05 +0000'
    expect(date).to.be.instanceOf Date
    expect(date.valueOf()).to.equal 2274814865000

  it 'parses dates created by Date.toUTCString()', ->
    date = Dropbox.Util.parseDate 'Fri, 31 Jan 2042 21:01:05 GMT'
    expect(date).to.be.instanceOf Date
    expect(date.valueOf()).to.equal 2274814865000

  it "parses dates created by IE's Date.toUTCString()", ->
    date = Dropbox.Util.parseDate 'Fri, 31 Jan 2042 21:01:05 UTC'
    expect(date).to.be.instanceOf Date
    expect(date.valueOf()).to.equal 2274814865000
