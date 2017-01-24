function getCurrentTabUrl(callback) {
  chrome.tabs.query({ currentWindow: true, active: true }, function (tabs) {
      callback(tabs[0].url);
  });
}

function renderResult(statusText) {
    document.getElementById('result').textContent = statusText;
}

function setStatus(statusText) {
    document.getElementById('status').textContent += statusText;
}

function clearStatus() {
    document.getElementById('status').textContent = "";
}

function LoadUrl(url, dataType, callback) {
    // load file    
    $.ajax({
        url: url,
        dataType: dataType,
        async: false
    })
    .done(callback);
}

function CheckArray(array, regex) {
    var checkedArray = [];
    array.forEach(function (item, index, array) {
        if (item.match(regex))
            checkedArray.push(item);
    });
    return checkedArray;
}

function createClickableResult(element, text) {
    var resultButton = document.createElement('div');

    resultButton.id = 'clickableResult';
    resultButton.innerHTML = text;
    resultButton.addEventListener('click', function () {
        document.execCommand('copy');

    });

    element.appendChild(resultButton);
}

function processHtml(html) {

    var file_m3u8 = /([\w\d-_.\\]+)\.m3u8/;
    var regex_page_m3u8 = /([\w\d-_.:\/\\]+\/)([\w\d-_.\\]+)\.m3u8/;
    var url_m3u8 = /(http+s*\:\/\/.*\/).*\.m3u8/;

    var m3u8Matches = html.match(regex_page_m3u8);

    var m3u8Files = [];

    // if matches found
    if (m3u8Matches != null) {
        setStatus("Found match.\n");

        m3u8Matches = CheckArray(m3u8Matches, url_m3u8);

        createClickableResult(document.getElementById('result'), m3u8Matches);
        
        m3u8Matches.forEach(function (item, index, array) {
            LoadUrl(item, 'text', function () {

            });
        });
        
        console.log(m3u8Files);
    }
}

function getFromPage(actionStr, callback) {
    getCurrentTabUrl(function (url) {
        chrome.tabs.getSelected(null, function (tab) {
            chrome.tabs.sendMessage(tab.id, { action: actionStr }, function (response) {
                if (response != null)
                    callback(response.message);
            });
        });
    });
}

function beginProcess() {
    clearStatus();
    getFromPage("getDOM", processHtml);
    getFromPage("getFrames", processHtml);    
}

function doStuff(html) {
    var regex_page_m3u8 = /([\w\d-_.:\/\\]+\/)([\w\d-_.\\]+)\.m3u8/;
    var url_m3u8 = /(http+s*\:\/\/.*\/).*\.m3u8/;

    var m3u8Matches = html.match(regex_page_m3u8);

    // if matches found
    if (m3u8Matches != null) {

        m3u8Matches = CheckArray(m3u8Matches, url_m3u8);

        createClickableResult(document.getElementById('result'), m3u8Matches);
    }
    else
        document.getElementById('result').textContent = "Nothing Found in DOM";
}

function doStuff2(htmlArray) {
    var regex_page_m3u8 = /([\w\d-_.:\/\\]+\/)([\w\d-_.\\]+)\.m3u8/;
    var url_m3u8 = /(http+s*\:.*\/).*\.m3u8/;

    var m3u8Matches = []; // array of matches

    if (htmlArray != null)
        htmlArray.forEach(function (item, index, array) {
            var match = item.match(regex_page_m3u8)
            if (match != null)
                // pushes matches from var match into m3u8Matches
                match.forEach(function (item, index, array) {
                    m3u8Matches.push(item);
                });
        });

    // if matches found
    if (m3u8Matches != null) {
        console.log(m3u8Matches);
        m3u8Matches = CheckArray(m3u8Matches, url_m3u8);

        createClickableResult(document.getElementById('result'), m3u8Matches);
    }
    else
        document.getElementById('result').textContent = "Nothing Found in iFrames";
}

document.addEventListener('DOMContentLoaded', function () {
    //document.getElementById("reload").addEventListener("click", beginProcess);

    getFromPage("getDOM", doStuff);
    getFromPage("getFrames", doStuff2);
});
