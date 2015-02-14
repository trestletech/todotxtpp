if typeof window isnt 'undefined'
  mocha.setup(
      ui: 'bdd', slow: 150, timeout: 15000, bail: false,
      ignoreLeaks: !!window.cordova)
else
  # Web Workers.
  mocha.setup(
      ui: 'bdd', slow: 150, timeout: 15000, bail: false,
      reporter: 'post-message', ignoreLeaks: false)
