started = false

start = ->
  return if started
  chrome.tabs.create url: 'test/html/browser_test.html', active: true
  started = true

chrome.runtime.onStartup.addListener start
chrome.runtime.onInstalled.addListener start
