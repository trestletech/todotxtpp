/**
 * Module dependencies.
 */
var util = require('util')
  , OAuth2Strategy = require('passport-oauth').OAuth2Strategy
  , InternalOAuthError = require('passport-oauth').InternalOAuthError;


/**
 * `Strategy` constructor.
 *
 * The Dropbox authentication strategy authenticates requests by delegating to
 * Dropbox using the OAuth 2.0 protocol.
 *
 * Applications must supply a `verify` callback which accepts an `accessToken`,
 * `refreshToken` and service-specific `profile`, and then calls the `done`
 * callback supplying a `user`, which should be set to `false` if the
 * credentials are not valid.  If an exception occured, `err` should be set.
 *
 * Options:
 *   - `clientID`      your Dropbox application's app key found in the App Console
 *   - `clientSecret`  your Dropbox application's app secret
 *   - `callbackURL`   URL to which Dropbox will redirect the user after granting authorization
 *
 * Examples:
 *
 *     passport.use(new DropboxStrategy({
 *         clientID: 'yourAppKey',
 *         clientSecret: 'yourAppSecret'
 *         callbackURL: 'https://www.example.net/auth/dropbox-oauth2/callback',
 *       },
 *       function(accessToken, refreshToken, profile, done) {
 *         User.findOrCreate(..., function (err, user) {
 *           done(err, user);
 *         });
 *       }
 *     ));
 *
 * @param {Object} options
 * @param {Function} verify
 * @api public
 */
function Strategy(options, verify) {
  options = options || {};
  options.authorizationURL = options.authorizationURL || 'https://www.dropbox.com/1/oauth2/authorize';
  options.tokenURL = options.tokenURL || 'https://api.dropbox.com/1/oauth2/token';
  options.scopeSeparator = options.scopeSeparator || ',';
  options.customHeaders = options.customHeaders || {};

  OAuth2Strategy.call(this, options, verify);
  this.name = 'dropbox-oauth2';
}

/**
 * Inherit from `OAuth2Strategy`.
 */
util.inherits(Strategy, OAuth2Strategy);


/**
 * Retrieve user profile from Dropbox.
 *
 * This function constructs a normalized profile, with the following properties:
 *
 *   - `provider`         always set to `github`
 *   - `id`               the user's Dropbox ID
 *   - `username`         the user's Dropbox username
 *   - `displayName`      the user's full name
 *   - `profileUrl`       the URL of the profile for the user on Dropbox
 *   - `emails`           the user's email addresses
 *
 * @param {String} accessToken
 * @param {Function} done
 * @api protected
 */
Strategy.prototype.userProfile = function(accessToken, done) {
  this._oauth2.get('https://api.dropbox.com/1/account/info', accessToken, function (err, body, res) {
    if (err) { return done(new InternalOAuthError('failed to fetch user profile', err)); }
    
    try {
      var json = JSON.parse(body);
      
      var profile = { provider: 'github' };
      profile.id = json.uid;
      profile.displayName = json.display_name;
      profile.emails = [{ value: json.email }];
      
      profile._raw = body;
      profile._json = json;
      
      done(null, profile);
    } catch(e) {
      done(e);
    }
  });
}


/**
 * Expose `Strategy`.
 */
module.exports = Strategy;
