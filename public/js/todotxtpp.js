(function(){
  var exports = window.Todotxt = {};

  var dbExtensions = exports.dbExtensions = ['.txt', '.text', '.ttxt'];

  $(document).ready(function(){
    // Bind for search events.
    $('#search-btn-container').click(function(e){
      var searchVal = $('#search-input').val();
      renderSearch(searchVal);
    });
    $('#search-input').bind("keyup keypress", function(e) {
      var code = e.keyCode || e.which;
      if (code == 13) {
        var searchVal = $('#search-input').val();
        e.preventDefault();
        renderSearch(searchVal);
        return false;
      }
    });
  });

  var onDBSuccess = exports.onDBSuccess = function(files){
    // We only get one file
    var link = files[0].link;

    // The dropbox API doesn't really expose what we want, but I don't want to
    // write a custom file chooser. So we're going to get the direct link and then
    // parse out the path to the file. This is absolutely vulnerable to them
    // changing their API, but... here goes!
    var path = 
      link.replace(/(http)?(s)?(:)?\/\/[^\/]+\/(\d+\/)?[^\/]+\/[^\/]+\//, '');

    $.ajax('/settings/path', {
      type: 'POST',
      data: {
        path: path
      }
    })
    .done(function(){
      // Great. The server now knows our path, but we're probably on a useless
      // "choose your file" page. Should we just refresh? Sure.
      location.reload();
    })
    .fail(function(){
      alert("Unable to set path.");
    });
  };

  /**
   * Perform a search for the given string using the local file.
   * @param searchVal The pattern for which we're searching -- can include special
   *   characters like @ and + to search for projects or contexts.
   **/
  var search = exports.search = function(searchVal){
    if (searchVal.trim().length === 0){
      // TODO flash warning
      return;
    }

    // TODO search
  }

  /**
   * Execute a search for the given string and render the results.
   **/
  var renderSearch = exports.renderSearch = function(searchVal){
    $('#search-input').val('');

    var results = search(searchVal);
    // TODO
  }
  
})();