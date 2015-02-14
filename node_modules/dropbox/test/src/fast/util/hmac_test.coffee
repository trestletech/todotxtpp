describe 'Dropbox.Util.hmac', ->
  it 'works for an empty message with an empty key', ->
    # Source:
    #     http://en.wikipedia.org/wiki/Hash-based_message_authentication_code#Examples_of_HMAC_.28MD5.2C_SHA1.2C_SHA256.29
    expect(Dropbox.Util.hmac('', '')).to.equal '+9sdGxiqbAgyS31ktx+3Y3BpDh0='

  it 'works for the non-empty Wikipedia example', ->
    expect(Dropbox.Util.hmac(
        'The quick brown fox jumps over the lazy dog', 'key')).to.
        equal '3nybhbi3iqa8ino29wqQcBydtNk='

  it 'works for the Oauth example', ->
    key = 'kd94hf93k423kf44&pfkkdhi9sl3r4s00'
    string = 'GET&http%3A%2F%2Fphotos.example.net%2Fphotos&file%3Dvacation.jpg%26oauth_consumer_key%3Ddpf43f3p2l4k3l03%26oauth_nonce%3Dkllo9940pd9333jh%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1191242096%26oauth_token%3Dnnch734d00sl2jdk%26oauth_version%3D1.0%26size%3Doriginal'
    expect(Dropbox.Util.hmac(string, key)).to.
        equal 'tR3+Ty81lMeYAr/Fid0kMTYa/WM='

describe 'Dropbox.Util.sha1', ->
  it 'works for an empty message', ->
    expect(Dropbox.Util.sha1('')).to.equal '2jmj7l5rSw0yVb/vlWAYkK/YBwk='
  it 'works for the FIPS-180 Appendix A sample 1', ->
    expect(Dropbox.Util.sha1('abc')).to.equal 'qZk+NkcGgWq6PiVxeFDCbJzQ2J0='
  it 'works for the FIPS-180 Appendix A sample 2', ->
    string = 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'
    expect(Dropbox.Util.sha1(string)).to.equal 'hJg+RBw70m66rkqh+VEp5eVGcPE='

describe 'Dropbox.Util.sha256', ->
  it 'works for an empty message', ->
    expect(Dropbox.Util.sha256('')).to.equal(
        '47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=')
  it 'works for the FIPS-180 Appendix A sample 1', ->
    expect(Dropbox.Util.sha256('abc')).to.equal(
        'ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=')
  it 'works for the FIPS-180 Appendix A sample 2', ->
    string = 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'
    expect(Dropbox.Util.sha256(string)).to.equal(
        'JI1qYdIGOLjlwCaTDD5gOaM85Flk/yFn9uzt1BnbBsE=')
  it 'works for the FIPS-180 Appendix A additional sample 8', ->
    string = (new Array(1001)).join 'A'
    expect(Dropbox.Util.sha256(string)).to.equal(
        'wuaGgjSJztIBf2BZuLI5MYtjZPbc2DXQpRkQWh6t1uQ=')
  it 'works for the FIPS-180 Appendix A additional sample 9', ->
    string = (new Array(1006)).join 'U'
    expect(Dropbox.Util.sha256(string)).to.equal(
        '9NYt3sDz3ZDqE4D6FqX/jcTFSyF0BlDySvxBIJA1UrA=')
