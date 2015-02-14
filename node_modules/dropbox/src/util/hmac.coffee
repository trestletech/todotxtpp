# HMAC-SHA1 implementation heavily inspired from
#   http://pajhome.org.uk/crypt/md5/sha1.js

do ->
  # Base64-encoded HMAC-SHA1.
  #
  # @private
  # This should only be used by {Dropbox.Util.Oauth}.
  #
  # @param {String} string the ASCII string to be signed
  # @param {String} key the HMAC key
  # @return {String} a base64-encoded HMAC of the given string and key
  Dropbox.Util.hmac = (string, key) ->
    arrayToBase64 hmacSha1(stringToArray(string), stringToArray(key),
                           string.length, key.length)

  # Base64-encoded SHA1.
  #
  # @private
  # This should only be used by {Dropbox.Util.Oauth}.
  #
  # @param {String} string the ASCII string to be hashed
  # @return {String} a base64-encoded SHA1 hash of the given string
  Dropbox.Util.sha1 = (string) ->
    arrayToBase64 sha1(stringToArray(string), string.length)

  Dropbox.Util.sha256 = (string) ->
    arrayToBase64 sha256(stringToArray(string), string.length)

  # SHA1 and HMAC-SHA1 versions that use the node.js builtin crypto.
  if Dropbox.Env.require
    try
      crypto = Dropbox.Env.require 'crypto'
      if crypto.createHmac and crypto.createHash
        Dropbox.Util.hmac = (string, key) ->
          hmac = crypto.createHmac 'sha1', key
          hmac.update string
          hmac.digest 'base64'
        Dropbox.Util.sha1 = (string) ->
          hash = crypto.createHash 'sha1'
          hash.update string
          hash.digest 'base64'
        Dropbox.Util.sha256 = (string) ->
          hash = crypto.createHash 'sha256'
          hash.update string
          hash.digest 'base64'
    catch requireError
      # The slow versions defined at the top of the file work everywhere.

  # HMAC-SHA1 implementation.
  #
  # @private
  # This method is not exported.
  #
  # @param {Array} string the HMAC input, as an array of 32-bit numbers
  # @param {Array} key the HMAC input, as an array of 32-bit numbers
  # @param {Number} length the length of the HMAC input, in bytes
  # @return {Array} the HMAC output, as an array of 32-bit numbers
  hmacSha1 = (string, key, length, keyLength) ->
    if key.length > 16
      key = sha1 key, keyLength

    ipad = (key[i] ^ 0x36363636 for i in [0...16])
    opad = (key[i] ^ 0x5C5C5C5C for i in [0...16])

    hash1 = sha1 ipad.concat(string), 64 + length
    sha1 opad.concat(hash1), 64 + 20

  # SHA1 implementation.
  #
  # @private
  # This method is not exported.
  #
  # @param {Array<Number>} string the SHA1 input, as an array of 32-bit
  #   numbers; the computation trashes the array
  # @param {Number} length the number of bytes in the SHA1 input; used in the
  #   SHA1 padding algorithm
  # @return {Array<Number>} the SHA1 output, as an array of 32-bit numbers
  sha1 = (string, length) ->
    string[length >> 2] |= 1 << (31 - ((length & 0x03) << 3))
    string[(((length + 8) >> 6) << 4) + 15] = length << 3

    state = Array 80
    a = 0x67452301
    b = 0xefcdab89
    c = 0x98badcfe
    d = 0x10325476
    e = 0xc3d2e1f0

    i = 0
    limit = string.length
    # Uncomment the line below to debug packing.
    # console.log string.map(xxx)
    while i < limit
      a0 = a
      b0 = b
      c0 = c
      d0 = d
      e0 = e

      for j in [0...80]
        if j < 16
          state[j] = string[(i + j) << 2 >> 2] | 0
        else
          n = (state[(j - 3) << 2 >> 2] | 0) ^ (state[(j - 8) << 2 >> 2] | 0) ^ 
              (state[(j - 14) << 2 >> 2] | 0) ^ (state[(j - 16) << 2 >> 2] | 0)
          state[j] = (n << 1) | (n >>> 31)

        t = (((((a << 5) | (a >>> 27)) + e) | 0) + state[j << 2 >> 2]) | 0
        if j < 20
          t = (t + ((((b & c) | (~b & d)) + 0x5a827999) | 0)) | 0
        else if j < 40
          t = (t + (((b ^ c ^ d) + 0x6ed9eba1) | 0)) | 0
        else if j < 60
          t = (t + (((b & c) | (b & d) | (c & d)) - 0x70e44324) | 0) | 0
        else
          t = (t + (((b ^ c ^ d) - 0x359d3e2a) | 0)) | 0
        e = d
        d = c
        c = (b << 30) | (b >>> 2)
        b = a
        a = t
        # Uncomment the line below to debug block computation.
        # console.log(xxx(v) for v in [a, b, c, d, e])
      a = (a0 + a) | 0
      b = (b0 + b) | 0
      c = (c0 + c) | 0
      d = (d0 + d) | 0
      e = (e0 + e) | 0
      i = (i + 16) | 0
    # Uncomment the line below to see the input to the base64 encoder.
    # console.log(xxx(v) for v in [a, b, c, d, e])
    [a, b, c, d, e]

  # SHA256 implementation.
  #
  # @private
  # This method is not exported.
  #
  # @param {Array<Number>} string the SHA256 input, as an array of 32-bit
  #   numbers; the computation trashes the array
  # @param {Number} length the number of bytes in the SHA256 input; used in the
  #   SHA256 padding algorithm
  # @return {Array<Number>} the SHA256 output, as an array of 32-bit numbers
  sha256 = (string, length) ->
    string[length >> 2] |= 1 << (31 - ((length & 0x03) << 3))
    string[(((length + 8) >> 6) << 4) + 15] = length << 3

    state = Array 80
    [a, b, c, d, e, f, g, h] = sha256Init

    i = 0
    limit = string.length
    # Uncomment the line below to debug packing.
    # console.log string.map(xxx)
    while i < limit
      a0 = a
      b0 = b
      c0 = c
      d0 = d
      e0 = e
      f0 = f
      g0 = g
      h0 = h
      for j in [0...64]
        if j < 16
          sj = state[j] = string[(i + j) << 2 >> 2] | 0
        else
          gamma0x = state[(j - 15) << 2 >> 2] | 0
          gamma0 = ((gamma0x << 25) | (gamma0x >>> 7)) ^
                   ((gamma0x << 14) | (gamma0x >>> 18)) ^
                   (gamma0x >>> 3)
          gamma1x = state[(j - 2) << 2 >> 2] | 0
          gamma1 = ((gamma1x << 15) | (gamma1x >>> 17)) ^
                   ((gamma1x << 13) | (gamma1x >>> 19)) ^
                   (gamma1x >>> 10)
          sj = state[j] = (((gamma0 + (state[(j - 7) << 2 >> 2] | 0)) | 0) +
                          ((gamma1 + (state[(j - 16) << 2 >> 2] | 0)) | 0)) | 0

        ch = (e & f) ^ (~e & g)
        maj = (a & b) ^ (a & c) ^ (b & c)
        sigma0 = ((a << 30) | (a >>> 2)) ^ ((a << 19) | (a >>> 13)) ^
                 ((a << 10) | (a >>> 22))
        sigma1 = ((e << 26) | (e >>> 6)) ^ ((e << 21) | (e >>> 11)) ^
                 ((e << 7) | (e >>> 25))
        t1 = (((((h + sigma1) | 0) + ((ch + sj) | 0)) | 0) +
             (sha256Key[j << 2 >> 2] | 0)) | 0
        t2 = (sigma0 + maj) | 0

        h = g
        g = f
        f = e
        e = (d + t1) | 0
        d = c
        c = b
        b = a
        a = (t1 + t2) | 0
        # Uncomment the line below to debug block computation.
        # console.log(['round', j])
        # console.log(xxx(v) for v in [a, b, c, d, e, f, g, h])

      a = (a0 + a) | 0
      b = (b0 + b) | 0
      c = (c0 + c) | 0
      d = (d0 + d) | 0
      e = (e0 + e) | 0
      f = (f0 + f) | 0
      g = (g0 + g) | 0
      h = (h0 + h) | 0
      i += 16

    # Uncomment the line below to see the input to the base64 encoder.
    # console.log(xxx(v) for v in [a, b, c, d, e, f, g, h])
    [a, b, c, d, e, f, g, h]

  # Uncomment the definition below for debugging.
  #
  # Returns the hexadecimal representation of a 32-bit number.
  xxx = (n) ->
    n = (1 << 30) * 4 + n if n < 0
    n.toString 16

  # The SHA256 initial vector.
  #
  # @private
  # This constant is not exported.
  sha256Init = []

  # The SHA256 round constants.
  #
  # @private
  # This constant is not exported.
  sha256Key = []

  # Generating code for sha256Init and sha256Key.
  do ->
    # @return {Number} the fractional part of a number times 2^32, rounded down
    fractional = (x) ->
      ((x - Math.floor(x)) * 0x100000000) | 0

    prime = 2
    for i in [0...64]
      loop
        isPrime = true
        factor = 2
        while factor * factor <= prime
          if prime % factor is 0
            isPrime = false
            break
          factor += 1
        break if isPrime
        prime += 1
        continue
      if i < 8
        sha256Init[i] = fractional Math.pow(prime, 1/2)
      sha256Key[i] = fractional Math.pow(prime, 1/3)
      prime += 1

    # Uncomment the line below to debug the constant-generating code.
    # console.log(xxx(v) for v in sha256Init)
    # console.log(xxx(v) for v in sha256Key)
  
  # Converts a 32-bit number array into a base64-encoded string.
  #
  # @private
  # This method is not exported.
  #
  # @param {Array} an array of big-endian 32-bit numbers
  # @return {String} base64 encoding of the given array of numbers
  arrayToBase64 = (array) ->
    string = ""
    i = 0
    limit = array.length * 4
    while i < limit
      i2 = i
      trit = ((array[i2 >> 2] >> ((3 - (i2 & 3)) << 3)) & 0xFF) << 16
      i2 += 1
      trit |= ((array[i2 >> 2] >> ((3 - (i2 & 3)) << 3)) & 0xFF) << 8
      i2 += 1
      trit |= (array[i2 >> 2] >> ((3 - (i2 & 3)) << 3)) & 0xFF

      string += _base64Digits[(trit >> 18) & 0x3F]
      string += _base64Digits[(trit >> 12) & 0x3F]
      i += 1
      if i >= limit
        string += '='
      else
        string += _base64Digits[(trit >> 6) & 0x3F]
      i += 1
      if i >= limit
        string += '='
      else
        string += _base64Digits[trit & 0x3F]
      i += 1
    string

  _base64Digits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  # Converts an ASCII string into array of 32-bit numbers.
  stringToArray = (string) ->
    array = []
    mask = 0xFF
    for i in [0...string.length]
      array[i >> 2] |= (string.charCodeAt(i) & mask) << ((3 - (i & 3)) << 3)
    array

