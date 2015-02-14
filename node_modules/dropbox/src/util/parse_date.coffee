# Workarounds for date parsing inconsistencies across platforms.

if (new Date('Fri, 31 Jan 2042 21:01:05 +0000')).valueOf() is 2274814865000
  Dropbox.Util.parseDate = (dateString) -> new Date dateString
else if Date.parse('Fri, 31 Jan 2042 21:01:05 +0000') is 2274814865000
  Dropbox.Util.parseDate = (dateString) -> new Date(Date.parse(dateString))
else
  # Safari needs manual date parsing.
  do ->
    parseDateRe =
        /^\w+\, (\d+) (\w+) (\d+) (\d+)\:(\d+)\:(\d+) (\+\d+|UTC|GMT)$/
    # Month names from http://tools.ietf.org/html/rfc2822#page-14
    parseDateMonths =
      Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5, Jul: 6, Aug: 7,
      Sep: 8, Oct: 9, Nov: 10, Dec: 11
    Dropbox.Util.parseDate = (dateString) ->
      return NaN unless match = parseDateRe.exec dateString
      new Date(Date.UTC(parseInt(match[3]), parseDateMonths[match[2]],
          parseInt(match[1]), parseInt(match[4]), parseInt(match[5]),
          parseInt(match[6]), 0))
