
function onDBSuccess(files){
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
}
