(function(){
  var exports = window.Todotxt = {};

  /**
   * Track file and revision # that we have downloaded.
   **/
  var revision = 0;
  var file = exports.file = '';

  /**
   * Track an integer array of the line numbers currently being shown
   * in the editor.
   **/
  var currentFilter = exports.currentFilter = null;

  var updateCallbacks = [];

  var dbExtensions = exports.dbExtensions = ['.txt', '.text', '.ttxt'];

  /**
   * Track whether or not the editor has been changed since the last update.
   **/
  var modified = false;

  // Store the local copy of the editor
  var editor = null;

  var ignoreNextHashchange = false;

  $(document).ready(function(){
    // Schedule a periodic check to check Dropbox.
    registerCheck();

    $('#archive-dones').click(function(){
      if (!confirm("This will archive all your completed tasks to a file named 'done.txt' in the same directory as your todo.txt file.\n\nAre you sure you want to continue?")){
        return;
      }

      $.ajax('/archive', {
        type: 'POST'
      })
      .then(function(data){
        
        renderFile(data);
      })
      .fail(function(xhr, status, err){
        $(document).trigger("add-alerts", [
            {
              'message': "Unable to archive completed tasks. Please try again later.",
              'priority': 'warning'
            }
          ]);
      });
    });

    $('#filters').sortable({
      update: function(event, ui) {
        var arr = $('#filters').sortable("toArray");
        $.ajax('/filters', {
          type: 'POST', 
          data : {
            action: 'order',
            filter: arr
          }
        })
        .fail(function(xhr, status, err){
          $(document).trigger("add-alerts", [
            {
              'message': "Unable to save new filter order. Please try again later.",
              'priority': 'warning'
            }
          ]);
        });
      }
    });
    $( "#filters" ).disableSelection();  

    $('#create-filter-ok').click(function(){
      var filterStr = $('#create-filter-input').val();
      if (filterStr.trim() === ''){
        return;
      }
      $('#createModal').modal('hide');
      $.ajax('/filters', {
        type: 'POST', 
        data : {
          action: 'add',
          filter: filterStr
        }
      })
      .done(function(data){
        $('#sidebar ul').append(formatSidebarLi(filterStr));
      })
      .fail(function(xhr, status, err){
        $(document).trigger("add-alerts", [
          {
            'message': "Unable to add list.",
            'priority': 'error'
          }
        ]);
      })
      .always(function(){
        $('#create-filter-input').val('');
      });
    });

    $('#filter-select').change(function(evt){
      $.bbq.pushState('#' + $('#filter-select').val());
    });

    $('.create-filter-option').click(function(event){
      $('#create-filter-input').attr('placeholder', $(this).data('example'));
      $('#create-filter-input').data('prefix', $(this).data('prefix'));
      $('#create-filter-input').val('');
      $(this).siblings().each(function(i, el){
        $(this).removeClass('active-filter-option');
      });
      $(this).addClass('active-filter-option');
    });

    $('#create-filter-input').on('keyup', function(event){
      var val = $(this).val();
      $('.create-filter-option').each(function(i, el){
        $(this).removeClass('active-filter-option');

        if (val.indexOf($(this).data('prefix')) === 0){
          // Select this option.
          $(this).addClass('active-filter-option');    
        }
      });

    });

    $('#create-filter-input').on('focus', function(event){
      // Placeholder should be empty while the user is typing.
      $(this).data('placeholder', $(this).attr('placeholder'));
      $(this).attr('placeholder', '');

      if ($(this).val() === ''){
        $(this).val($(this).data('prefix'));
      }
    });

    $('#create-filter-input').on('blur', function(){
      // Restore the placeholder text
      $(this).attr('placeholder', $(this).data('placeholder'));

      var prefix = $(this).data('prefix');
      if ($(this).val() === prefix){
        $(this).val('');
      }
    });

    $('#sidebar').on('click', '.delete-list-btn',function(event){
      var menuItem = $(this).closest('li a');
      
      var filterStr = menuItem.data('name');
      $('#delete-list-name').text(filterStr);
      
      $('#delete-filter-btn').one('click', function(){
        $.ajax('/filters', {
          type: 'POST', 
          data : {
            action: 'delete',
            filter: filterStr
          }
        })
        .done(function(data){
          $('li', '#sidebar').each(function(i, el){
            var name = $('a', $(el)).data('name');
            if (name === filterStr){
              $(this).remove();
            }
          });
        })
        .fail(function(xhr, status, err){
          $(document).trigger("add-alerts", [
            {
              'message': "Unable to delete list.",
              'priority': 'error'
            }
          ]);
        });
        $('#deleteFilter').modal('hide');
      });

      $('#deleteFilter').modal('show');
      event.stopPropagation();
      return false;
    });

    window.onbeforeunload = function(){
      if (modified){
        return 'You have changes that have not yet been saved to Dropbox. If you leave, any unsaved changes will be lost.';
      }
      return;
    };

    // Add a clear button on the search input that takes us back home
    $('#clear-search').click(function(){
      $.bbq.pushState();
    });


    // Update the editor/alerts
    addUpdateHook(function(data, external){
      if (!external){
        // We can ignore updates from the current page, since the editor would
        // have already been updated as the user typed.
        return;
      }
      /**
       * Register a periodic check to ensure the version on Dropbox hasn't updated
       * beyond the version that we have. If it has and we've modified, show a 
       * persistent error. If it has and we haven't modified, just update to the 
       * latest remote version.
       **/
      if (modified){
        // The remote version is more recent.
        $('#persAlerts').attr('class', 'alert alert-danger');            
        $('#persAlerts').text('The remote Todo file has been updated. Your local changes cannot be saved. Please refresh the page to view the updates and discard your local changes.');                          
      } else{
        setText(data.text, -1);
      }
    });

    // Bind for search events.
    $('#search-btn-container').click(function(e){
      var searchVal = $('#search-input').val();
      if (searchVal.trim() === ''){
        return;
      }
      renderSearch(searchVal);
    });
    $('#search-input').bind("keypress", function(e) {
      var code = e.keyCode || e.which;
      if (code == 13) {
        var searchVal = $('#search-input').val();
        if (searchVal.trim() === ''){
          return;
        }
        e.preventDefault();
        renderSearch(searchVal);
        return false;
      }
    });

    // Setup our router.
    $(window).bind( 'hashchange', function( event ) {
      if (modified && !ignoreNextHashchange){
        $(document).trigger("add-alerts", [
          {
            'message': "You must save your changes here before you can change pages.",
            'priority': 'warning'
          }
        ]);
        ignoreNextHashchange = true;
        history.back();
        return false;
      }

      if (ignoreNextHashchange){
        // We were instructed to ignore this hash change.
        ignoreNextHashchange = false;
        return;
      }

      var hash_str = event.fragment,
        searchStr = event.getState('search');
      // Deselect any "active" sidebar item.
      $('a', '#sidebar').each(function(i, a){
        $(a).removeClass();
      });

      if (searchStr){
        // Render search        
        var results = search(searchStr);
        
        // Set the searchbar input if it wasn't already set.
        $('#search-input').val(searchStr);
        $('#clear-search').show();

        filterTo(results);
        return;
      } 

      $('#clear-search').hide();

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
      modified = false;

    });
    $(window).trigger( 'hashchange' );
  });

  var getRevision = exports.getRevision = function(){
    return revision;
  };

  /**
   * Add a function callback when the Todolist file is updated.
   **/
  var addUpdateHook = exports.addUpdateHook = function(callback){
    updateCallbacks.push(callback);
  };

  var removeUpdateHook = exports.removeUpdateHook = function(callback){
    updateCallbacks.splice(updateCallbacks.indexOf(callback),1);
  };

  var save = exports.save = function(callback){    
    var appliedFilter = currentFilter;    
    var appliedText = editor.getSession().getValue();

    var cf;
    if (typeof currentFilter === 'undefined'){
      cf = false;
    } else {
      cf = currentFilter;
    }

    $.ajax('/list', {
      type: 'POST', 
      data : {
        text: editor.getSession().getValue(),
        revision: revision,
        filter: cf
      }
    })
    .done(function(data){      
      if (typeof data === 'undefined'){
        // Can return an HTTP 204 if we did a no-op on the server.
        callback(null, null);
        return;
      }

      skipUpdates = false;

      if (appliedText !== editor.getValue()) {
        console.log("Skipping editor update due to local edits.");
        skipUpdates = true;
      }

      if (!skipUpdates){
        if (appliedFilter){
          // Need to merge the changes in to our local copy
          file = mergeEdits(file, appliedFilter, appliedText);
        } else {
          file = appliedText;
        }
      }
      
      revision = data.revision;
      callback(null, data);

      if (!skipUpdates){
        modified = false;
        $(window).trigger( 'hashchange' );

        fireUpdate({text: file, revision: revision}, false);
      }
    })
    .fail(function(xhr, status, err){
      callback(err, null);
    });
  };

  // An array of auto-complete suggestions -- currently projects and contexts.
  exports.dictionary = [];

  var getList = exports.getList = function(callback, forceRefresh){
    if (arguments.length < 2){
      forceRefresh = false;
    }

    if (!forceRefresh && file){
      return callback(null, {text: file, revision: revision});
    }

    $.ajax('/list')
    .done(function(data){
      renderFile(data);

      callback(null, data);
    })
    .fail(function(xhr, status, err){
      callback(err, null);
    });
  };

  function renderFile(data){
    revision = data.revision;

    file = data.text;

    exports.dictionary = [];
    var keywords = file.match(new RegExp("(^\|[\\s])([\\+\\@]\\w+)", 'g'));
    if (keywords){
      $.each(keywords, function(ind, key){
        exports.dictionary.push(key.trim());
      });  
    }      

    // We got a new file. We may need to re-render.
    $(window).trigger('hashchange');
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

  exports.setEditor = function(edtr){
    editor = edtr;
    editor.getSession().on('change', function(e) {
      modified = true;
    });
    return editor;
  };

  var setText = exports.setText = function(text, force){
    if (text == editor.getValue()){
      // No need to trigger update events if nothing's been set.
      modified = false;
      return;
    }


    if (modified && !force){
      throw new Error("Can't update the file since it's been modified");
    }

    editor.setValue(text, -1);

    modified = false;
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

    var splitLine = file.split(/\r?\n/);
    $.each(splitLine, function(lineNum, line){
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
  };

  /**
   * Execute a search for the given string and render the results.
   **/
  var renderSearch = exports.renderSearch = function(searchVal){
    var results = search(searchVal);
    $.bbq.pushState({search: searchVal});
  };

  var filterTo = exports.filterTo = function(lineNums){

    if (!editor){
      return;
    }

    currentFilter = lineNums;

    if (!lineNums){
      setText(file);
      return;
    }

    var filtered = file.split(/\r?\n/);
    filtered = $.grep(filtered, function(el, i){
      return ($.inArray(i+1, lineNums) >= 0);
    });

    var str = filtered.join('\n');
    setText(str);
  };


  // Allow the external caller to temporarily disable the periodic check.
  // Can be used if, for instance, the user is typing and we have a save
  // scheduled.
  checkEnabled = true;
  setCheck = exports.setCheck = function(enabled){
    checkEnabled = enabled;
  };

  /**
   * Register a periodic check to keep our file up-to-date with the one on
   * Dropbox.
   **/
  function registerCheck(){
    window.setInterval(function(){
      // Check is (momentarily) disabled, so don't query this round.
      if (!checkEnabled){
        return;
      }

      if (!revision){
        // There's nothing we can do yet.
        return;
      }
      $.ajax('/revision')
      .done(function(rev){
        if (rev > revision){
          getList(function(err, update){
            if (!err){
              fireUpdate(update, true);
            }
          }, true);
        }
      });
    }, 15000);
  }

  /**
   * Fires an update to call all callback functions.
   * @param update The update object with the text and revision #.
   * @param external Boolean representing whether the update came from an
   *   external source (true) or this application (false).
   **/
  function fireUpdate(update, external){
    $.each(updateCallbacks, function(i, cb){
      cb(update, external);
    });
  }

  /**
   * Gets the appropriate HTML for the icon and label for a sidebar widget
   * based on the string title.
   **/
  function formatSidebarLi(str){
    var toReturn = '<li><a href = "#'+str+'" data-name="'+str+'">';
    if (str.match(/^\+/)){
      toReturn += '<div class="list-icon list-icon-plus">+</div>';
      str = str.substring(1);
    } else if (str.match(/^@/)){
      toReturn += '<div class="list-icon list-icon-at">@</div>';
      str = str.substring(1);
    } else if (str.match(/^\(\w(\-\w)?\)/)){
      toReturn += '<i class="fa fa-star-o list-icon"></i>';
    }
    toReturn += '<i class = "fa fa-times delete-list-btn"></i>';
    toReturn += str+'</a></li>';
    return toReturn;
  }

  var activateEditor = exports.activateEditor = function(){
    var editor;
    var savebtn;

    $(document).ready(function(){
      savebtn = $('#save-btn').ladda();

      editor = Todotxt.setEditor(ace.edit("ace-editor"));

      editor.getSession().setMode("ace/mode/todotxt");
      editor.setShowPrintMargin(false);
      editor.getSession().setUseWrapMode('free');

      Todotxt.getList(function(err, data){
        if (err){
          $(document).trigger("add-alerts", [
            {
              'message': "Unable to load file from Dropbox. Please try again later.",
              'priority': 'error'
            }
          ]);
          return;
        }

        var langTools = ace.require("ace/ext/language_tools");
        var Autocomplete = ace.require("ace/autocomplete").Autocomplete;
        editor.setOptions({enableBasicAutocompletion: true});

        // Clear out the default completers
        while (editor.completers.length > 0){
          // Can't just assign to a new array -- references get messed up. Just empty.
          editor.completers.pop();
        }

        var dictCompleter = {
          getCompletions: function(editor, session, pos, prefix, callback) {
            if (prefix.length === 0) { callback(null, []); return; }

            // From http://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
            function escapeRegExp(str) {
              return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&");
            }

            var matches = [];
            $.each(Todotxt.dictionary, function(ind, val){
              if (val.match(new RegExp('^' + escapeRegExp(prefix), "i"))){
                matches.push({name: val, value: val});
              }                
            });

            callback(null, matches);
          }
        };

        langTools.addCompleter(dictCompleter);

        // Enable tab for auto-completion
        editor.commands.addCommand({
          name: "startAutocomplete",
          exec: function(editor) {

            if (!editor.completer)
              editor.completer = new Autocomplete();
            editor.completer.autoInsert = 
              editor.completer.autoSelect = true;
            editor.completer.showPopup(editor);
            // needed for firefox on mac
            editor.completer.cancelContextMenu();
          },
          bindKey: "tab"
        });

        SAVE_FREQUENCY = 5000; // max interval for automatic saves
        saveTimer = null;
        lastSave = Date.now();    

        // The function to eval when we want to save.
        saveFun = function(){
          lastSave = Date.now();
          saveFile(function(){
            // Restore the periodic check for external updates.
            Todotxt.setCheck(true);
          });

          // Reset the timer.
          clearInterval(saveTimer);
          saveTimer = null;
        };

        // This will be logged as a keystroke that fires a save function, but
        // one extra save probably isn't the end of the world.
        editor.commands.addCommand({
          name:"save",
          bindKey: {win: "Ctrl-S", mac: "Command-S"},
          exec: saveFun
        });

        // Listen for keyboard interactions with the editor so we can
        // auto-save.
        $('#ace-editor').keyup(function(e) {
          if (saveTimer !== null) {
            // We already have a save scheduled
            return;
          }

          tDiff = Date.now() - lastSave;

          if (tDiff >= SAVE_FREQUENCY) {
            // Then we can just save now
            setTimeout(saveFun, 0);
          } else {
            // Temporarily disable the periodic checks for external updates
            // since our own saves will look like external updates by the time
            // the AJAX makes the round-trip and the editor has changed.
            Todotxt.setCheck(false);

            // We need to schedule a save
            saveTimer = setTimeout(saveFun, SAVE_FREQUENCY - tDiff);
          }
        }); 

      }, true);
    });

    saveFile = function(cb){
      savebtn.ladda('start');

      Todotxt.save(function(err, data){      
        if (cb){
          cb();
        }

        savebtn.ladda('stop');

        if (err){
          $(document).trigger("add-alerts", [
            {
              'message': "Error saving file: " + status,
              'priority': 'error'
            }
          ]);
          return;
        }

        if (data && data.errors && data.errors.length > 0){
          $(document).trigger("add-alerts", [
            {
              'message': data.errors[0],
              'priority': 'error'
            }
          ]);
          return;
        }
      });
    };

    function resizeAce() {    
      // The summed height of everything else on the screen for either wide or narrow views
      sHeight = $('.navbar').outerHeight(true) +$('#footer').outerHeight(true) + $('#save-row').outerHeight(true);
      sHeight += 20; // gap on absolutely positioned footer

      if ($('.device-xs').is(':visible')){
        sHeight += $('#filter-select').outerHeight(true);
      }

      sHeight = $(window).height() - sHeight;

      $('#sidebar-col').height(sHeight);

      $("#ace-editor").height(sHeight); 
      editor.resize();
    }
    $(window).resize(resizeAce);
    setTimeout(resizeAce,0); // Let Bootstrap do its thing first.  
  }
})();


