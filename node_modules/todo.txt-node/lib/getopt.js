//
//  getopt.js    Finnbarr P. Murphy March 2010
//
//  Based on BSD getopt.c  Use subject to BSD license.
//
//  For details of how to use this function refer to
//  the BSD man page for getopt(3). GNU-style long
//  options are not supported.
//

resetopt = function() {
    opterr = 1;                          // print error message
    optind = 0;                          // index into parent argv array
    optopt = "";                         // character checked for validity
    optreset = 0;                        // reset getopt
    optarg = "";                         // option argument
}

resetopt();

getopt = function(nargv, ostr)
{
    if ( typeof getopt.place == 'undefined' ) {
        getopt.place =  "";              // static string, option letter processing
        getopt.iplace = 0;               // index into string
    }

    var oli;                             // option letter list index

    if (optreset > 0 || getopt.iplace == getopt.place.length) {
        optreset = 0;
        getopt.place = nargv[optind]; getopt.iplace = 0;
        if (optind >= nargv.length || getopt.place.charAt(getopt.iplace++) != "-") {
            // argument is absent or is not an option
            getopt.place = ""; getopt.iplace = 0;
            return("");
        }
        optopt = getopt.place.charAt(getopt.iplace++);
        if (optopt == '-' && getopt.iplace == getopt.place.length) {
            // "--" => end of options
            ++optind;
            getopt.place = ""; getopt.iplace = 0;
            return("");
        }
        if (optopt == 0) {
            // Solitary '-', treat as a '-' option
            getopt.place = ""; getopt.iplace = 0;
            if (ostr.indexOf('-') == -1)
                return("");
            optopt = '-';
        }
    } else
         optopt = getopt.place.charAt(getopt.iplace++);

    // see if option letter is what is wanted
    if (optopt == ':' || (oli = ostr.indexOf(optopt)) == -1) {
        if (getopt.iplace == getopt.place.length)
            ++optind;
        if (opterr && ostr.charAt(0) != ':')
            console.error("illegal option -- " + optopt);
        return ('?');
    }

    // does this option require an argument?
    if (ostr.charAt(oli + 1) != ':') {
         // does not need argument
         optarg = null;
         if (getopt.iplace == getopt.place.length)
             ++optind;
    } else {
       //  Option-argument is either the rest of this argument or the entire next argument.
       if (getopt.iplace < getopt.place.length) {
            optarg = getopt.place.substr(getopt.iplace);
       } else if (nargv.length > ++optind) {
            optarg = nargv[optind];
       } else {
            // option argument absent
            getopt.place = ""; getopt.iplace = 0;
            if (ostr.charAt(0) == ':') {
                 return (':');
           }
            if (opterr)
                 console.error("option requires an argument -- " + optopt);
            return('?');
        }
        getopt.place = ""; getopt.iplace = 0;
        ++optind;
    }

    return (optopt);
}
