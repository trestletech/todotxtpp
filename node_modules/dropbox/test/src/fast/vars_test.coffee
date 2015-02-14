describe 'vars at the top of the dropbox.js function', ->
  beforeEach (done) ->
    unless testXhrServer
      @vars = null
      return done()

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

    # Read the un-minified dropbox.js file and parse the top "vars" line.
    xhr = new Dropbox.Util.Xhr 'GET', testXhrServer + '/lib/dropbox.js'
    xhr.prepare().send (error, data) =>
      expect(error).not.to.be.ok
      @dropbox_js = data
      for line in data.split "\n"
        match = /^\s*var(.*)(,|;)$/.exec(line)
        continue unless match
        @vars = for varSection in match[1].split(',')
          varSection.trim().split(' ', 2)[0]
        break
      done()

  afterEach ->
    if @node_js
      @XMLHttpRequest.nodejsSet httpsAgent: @oldAgent

  it 'contains Dropbox', ->
    expect(@vars).to.contain 'Dropbox'

  it 'only contains Dropbox and Dbx* vars', ->
    badVars = []
    for variable in @vars
      continue if variable is 'Dropbox'
      continue if /^Dbx[A-Z]/.test(variable)
      badVars.push variable
    expect(badVars).to.be.empty
