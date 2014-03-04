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
    $('#search-input').bind("keypress", function(e) {
      var code = e.keyCode || e.which;
      if (code == 13) {
        var searchVal = $('#search-input').val();
        e.preventDefault();
        renderSearch(searchVal);
        return false;
      }
    });

    // Setup our router.
    $(window).bind( 'hashchange', function( event ) {
      var hash_str = event.fragment,
        searchStr = event.getState('search');
      // Deselect any "active" sidebar item.
      $('a', '#sidebar').each(function(i, a){
        $(a).removeClass();
      });

      if (searchStr){
        // Render search        
        var results = search(searchStr);
        filterTo(results);
        return
      } 

      if (!hash_str){
        hash_str = 'ALL';
      } 
      
      hash_str = hash_str.toUpperCase();

      // On a named list

      // Clear search input.
      $('#search-input').val('');

      // Mark as active
      $('a', '#sidebar').each(function(i, a){
        if ($(a).attr('data-name').toUpperCase() === hash_str){
          $(a).addClass('active');
        }
      });

      if (hash_str.toUpperCase() === "ALL"){
        filterTo();
      } else{
        filterTo(search(hash_str));
      }

    });
    $(window).trigger( 'hashchange' );
  });

  /**
   * Track file revision that we have downloaded.
   **/
  var revision = 0;

  var getRevision = exports.getRevision = function(){
    return revision;
  }

  /**
   * Track an integer array of the line numbers currently being shown
   * in the editor.
   **/
  var currentFilter = exports.currentFilter = null;

  var save = exports.save = function(callback){
    
    $.ajax('/list', {
      type: 'POST', 
      data : {
        text: editor.getSession().getValue(),
        revision: revision,
        filter: currentFilter
      }
    })
    .done(function(data){
      revision = data.revision;
      callback(null, data);
    })
    .fail(function(xhr, status, err){
      callback(err, null);
    });
  }

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
      revision = data.revision;
      callback(null, data);
    })
    .fail(function(xhr, status, err){
      callback(err, null);
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
      return trimmed.toUpperCase();
    });

    var matches = new Array(searchVals.length);
    for (var i = 0; i < matches.length; i++){
      matches[i] = [];
    }

    $.each(file.text.split('\n'), function(lineNum, line){
      line = line.toUpperCase();
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
    var results = search(searchVal);
    $.bbq.pushState({search: searchVal});
  }

  var filterTo = exports.filterTo = function(lineNums){
    editor = ace.edit("ace-editor");

    currentFilter = lineNums;

    if (!lineNums){
      editor.setValue(file.text, -1);
      return;
    }

    var filtered = file.text.split('\n');
    filtered = $.grep(filtered, function(el, i){
      return ($.inArray(i+1, lineNums) >= 0);
    });

    editor.setValue(filtered.join('\n'), -1);
  }
  
})();