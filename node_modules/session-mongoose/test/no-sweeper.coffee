describe "session-mongoose sweeper off", ->
  assert = require('assert')
  should = require('should')
  SessionStore = require('..')(require('connect'))
  store = undefined

  store = new SessionStore
    url: "mongodb://localhost/session-mongoose-test-no-sweeper"
    sweeper: false
    interval: 100 # ms

  reset = ->
    store.clear()

  it "should NOT remove expired session within sweeper interval", (done) ->
    reset()
    store.set '321',
      cookie:
        expires: new Date(Date.now() + 10)
      name: 'don'
      value: '456'
    , (err, ok) ->
      assert.ifError err, "SessionStore.set should not return error"
      assert.equal ok, true, "SessionStore.set should return ok"
      setTimeout ->
        assert.equal store.sweeps, 0, "sweep count shouldn't change"
        # reset()
        done()
      , 3000
