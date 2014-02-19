spawn = require('child_process').spawn

_current_cmd = null
run = (command, options, callback) ->
  if !callback and typeof options is 'function'
    callback = options
    options = {}
  else
    options or= {}
  if /^win/i.test(process.platform)  # Awful windows hacks.
    command = command.replace(/\//g, '\\')
    cmd = spawn 'cmd', ['/C', command]
  else
    cmd = spawn '/bin/sh', ['-c', command]
  _current_cmd = cmd
  cmd.stdout.on 'data', (data) ->
    process.stdout.write data unless options.noOutput
  cmd.stderr.on 'data', (data) ->
    process.stderr.write data unless options.noOutput
  cmd.on 'exit', (code) ->
    _current_cmd = null
    if code isnt 0 and !options.noExit
      console.log "Non-zero exit code #{code} running\n    #{command}"
      process.exit 1
    callback(code) if callback?
  null

process.on 'SIGHUP', ->
  _current_cmd.kill() if _current_cmd isnt null

module.exports = run
