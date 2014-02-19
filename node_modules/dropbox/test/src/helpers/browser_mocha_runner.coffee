runTests = ->
  runner = null
  runner = mocha.run()
  runner.on 'end', ->
    failures = @failures || 0
    total = @total || 0
    image = new Image()
    image.src = "/diediedie?failed=#{failures}&total=#{total}";
    image.onload = ->
      null

if window.cordova
  document.addEventListener 'deviceready', runTests
else
  window.addEventListener 'load', runTests
