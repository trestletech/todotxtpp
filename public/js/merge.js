

/**
 * @param file A string containing the whole file.
 * @param lineNums An array containing the line numbers which are included in 
 *   the document being edited. Expected to be 1-indexed
 * @param edited A string containing the edited portion of the file represented
 *   by lineNums.
 * @return 'file' with the edits incorporated in.
 **/
function mergeEdits(file, lineNums, edited){
  var editedLines = edited.split(/\r?\n/);
  var lines = file.split(/\r?\n/);

  // Node and browser-compliant loop needed, so...
  for (var i = 0; i < Math.max(editedLines.length, lineNums.length); i++){
    // 1-Indexed
    var lineNum;
    if (i < lineNums.length){
      lineNum = lineNums[i]-1;
    } else{
      // Add to the end of the file.
      lineNum = lines.length;
    }

    if (lineNum > lines.length){
      throw new Error("Invalid line number " + lineNum + " on a " + lines.length + 
        " line file.");
    }

    if (i < editedLines.length){
      lines[lineNum] = editedLines[i];  
    } else{
      // We must've deleted a line.
      lines[lineNum] = null;
    }
  }

  for (i = 0; i < lines.length; i++){
    if (lines[i] === null){
      // remove line and pull pointer back one if there are more elements
      lines.splice(i, 1);
      if ((i + 1) < lines.length){
        i--;
      }
    }
  }

  return lines.join('\n');
}

if (typeof module !== "undefined" && module.exports){
  module.exports = mergeEdits;
}
