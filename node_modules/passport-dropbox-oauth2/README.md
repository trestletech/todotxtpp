# Passport-Dropbox-OAuth2

[Passport](http://passportjs.org/) strategy for authenticating with [Dropbox](https://dropbox.com/)
using the OAuth 2.0 API.

This module lets you authenticate using Dropbox in your Node.js applications.
By plugging into Passport, Dropbox authentication can be easily and
unobtrusively integrated into any application or framework that supports
[Connect](http://www.senchalabs.org/connect/)-style middleware, including
[Express](http://expressjs.com/).

## Install

    $ npm install passport-dropbox-oauth2

## Usage

#### Configure Strategy

The Dropbox authentication strategy authenticates users using a Dropbox account
and OAuth 2.0 tokens.  The strategy requires a `verify` callback, which accepts
these credentials and calls `done` providing a user, as well as `options`
specifying a client ID, client secret, and callback URL.

    passport.use(new DropboxOAuth2Strategy({
        clientID: GITHUB_CLIENT_ID,
        clientSecret: GITHUB_CLIENT_SECRET,
        callbackURL: "https://www.example.net/auth/dropbox-oauth2/callback"
      },
      function(accessToken, refreshToken, profile, done) {
        User.findOrCreate({ providerId: profile.id }, function (err, user) {
          return done(err, user);
        });
      }
    ));

#### Authenticate Requests

Use `passport.authenticate()`, specifying the `'dropbox-oauth2'` strategy, to
authenticate requests.

For example, as route middleware in an [Express](http://expressjs.com/)
application:

    app.get('/auth/dropbox',
      passport.authenticate('dropbox-oauth2'));

    app.get('/auth/dropbox/callback', 
      passport.authenticate('dropbox-oauth2', { failureRedirect: '/login' }),
      function(req, res) {
        // Successful authentication, redirect home.
        res.redirect('/');
      });

## Examples

Examples not yet provided

## Tests

Tests not yet provided


## Credits

  - [Florian Heinemann](http://twitter.com/florian__h/)

  This strategy is based on Jared Hanson's GitHub strategy for passport:  
  - [Jared Hanson](http://github.com/jaredhanson)

## License

[The MIT License](http://opensource.org/licenses/MIT)

Copyright (c) 2013-2014 Florian Heinemann <[http://twitter.com/florian__h/](http://twitter.com/florian__h/)>

