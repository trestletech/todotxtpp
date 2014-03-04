

/**
 * @param file A string containing the whole file.
 * @param lineNums An array containing the line numbers which are included in 
 *   the document being edited. Expected to be 1-indexed
 * @param edited A string containing the edited portion of the file represented
 *   by lineNums.
 * @return 'file' with the edits incorporated in.
 **/
function mergeEdits(file, lineNums, edited){
  var editedLines = edited.split('\n');
  var lines = file.split('\n');

  if (editedLines.length !== lineNums.length){
    throw new Error("Invalid merge requsted with " + lineNums.length + 
      " lines specified, but " + editedLines.length + " lines provided.");
  }

  // Node and browser-compliant loop needed, so...
  for (var i = 0; i < lineNums.length; i++){
    // 1-Indexed
    var lineNum = lineNums[i]-1;

    if (lineNum > lines.length){
      throw new Error("Invalid line number " + lineNum + " on a " + lines.length + 
        " line file.");
    }
    lines[lineNum] = editedLines[i];
  }

  return lines.join('\n');
}

if (typeof module !== "undefined" && module.exports){
  module.exports = mergeEdits;
}