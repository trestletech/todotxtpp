# Implementations of atob and btoa for IE and node.js.

if typeof Dropbox.Env.global.atob is 'function' and
    typeof Dropbox.Env.global.btoa is 'function'
  # Modern browsers and Web workers.

  # NOTE: atob/btoa will crash in some browsers if not called on window
  Dropbox.Util.atob = (string) -> Dropbox.Env.global.atob string
  Dropbox.Util.btoa = (base64) -> Dropbox.Env.global.btoa base64

else if Dropbox.Env.global.require and Dropbox.Env.global.Buffer
  # node.js
  Dropbox.Util.atob = (arg) ->
    buffer = new Buffer arg, 'base64'
    (String.fromCharCode(buffer[i]) for i in [0...buffer.length]).join ''
  Dropbox.Util.btoa = (arg) ->
    buffer = new Buffer(arg.charCodeAt(i) for i in [0...arg.length])
    buffer.toString 'base64'
else
  do ->
    # IE < 10, no standard atob / btoa functions.
    base64Digits =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    btoaNibble = (accumulator, bytes, result) ->
      limit = 3 - bytes
      accumulator <<= limit * 8
      i = 3
      while i >= limit
        result.push base64Digits.charAt((accumulator >> (i * 6)) & 0x3F)
        i -= 1
      i = bytes
      while i < 3
        result.push '='
        i += 1
      null
    atobNibble = (accumulator, digits, result) ->
      limit = 4 - digits
      accumulator <<= limit * 6
      i = 2
      while i >= limit
        result.push String.fromCharCode((accumulator >> (8 * i)) & 0xFF)
        i -= 1
      null

    Dropbox.Util.btoa = (string) ->
      result = []
      accumulator = 0
      bytes = 0
      for i in [0...string.length]
        accumulator = (accumulator << 8) | string.charCodeAt(i)
        bytes += 1
        if bytes is 3
          btoaNibble accumulator, bytes, result
          accumulator = bytes = 0

      if bytes > 0
        btoaNibble accumulator, bytes, result
      result.join ''

    Dropbox.Util.atob = (base64) ->
      result = []
      accumulator = 0
      digits = 0
      for i in [0...base64.length]
        digit = base64.charAt i
        break if digit is '='
        accumulator = (accumulator << 6) | base64Digits.indexOf(digit)
        digits += 1
        if digits is 4
          atobNibble accumulator, digits, result
          accumulator = digits = 0

      if digits > 0
        atobNibble accumulator, digits, result
      result.join ''
