(function(){
  var exports = window.Todotxt = {};

  var file = exports.file = '';

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

  var getList = exports.getList = function(callback, forceRefresh){
    if (arguments.length < 2){
      forceRefresh = false;
    }

    if (!forceRefresh && file){
      return callback(null, file);
    }

    $.ajax('/list')
    .done(function(data){
      file = data;
      callback(null, data);
    })
    .fail(function(xhr, status){
      callback(new Error('Error downloading file: ' + status), null);
    });
  }

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
   * @param searchVal A string or array of strings representing the pattern for 
   *   which we're searching -- can include special characters like @ and + to 
   *   search for projects or contexts.
   * @return If searchVals is a string, returns a single array of lineNumbers
   *   which match the pattern. If searchVals is an array, returns an array
   *   of arrays in which the outer index corresponds to the searchVals array,
   *   and the inner indices are the line numbers on which a match was found.
   **/
  var search = exports.search = function(searchVals){
    var singleMode = false;

    // Nest in an array
    if (typeof searchVals !== "object"){
      singleMode = true;
      searchVals = [searchVals];
    }

    searchVals = $.map(searchVals, function(searchVal){
      var trimmed = searchVal.trim();
      if (trimmed.length === 0){
        return null;
      }
      return trimmed;
    });

    var matches = new Array(searchVals.length);
    for (var i = 0; i < matches.length; i++){
      matches[i] = [];
    }

    $.each(file.text.split('\n'), function(lineNum, line){
      $.each(searchVals, function(valNum, searchVal){
        if (searchVal && line.indexOf(searchVal) >= 0){
          // 1-Indexed line numbers match the editor.
          matches[valNum].push(lineNum+1);
        }        
      });
    });

    if (singleMode){
      matches = matches[0];
    }    
    return matches;
  }

  /**
   * Execute a search for the given string and render the results.
   **/
  var renderSearch = exports.renderSearch = function(searchVal){
    // Clear out the old search box if we're rendering results.
    $('#search-input').val('');

    var results = search(searchVal);
    
    // TODO
  }
  
})();