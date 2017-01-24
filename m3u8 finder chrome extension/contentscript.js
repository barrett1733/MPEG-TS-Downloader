chrome.extension.onMessage.addListener(function (request, sender, sendMessage) {
    if (request.action == "getDOM") {
        console.log("Sending dom.\n");
        sendMessage({ message: document.documentElement.innerHTML });
        console.log("Sent dom.\n");
    }
    else if (request.action == "getFrames") {
        console.log("Sending iframes.\n");
        var frames = document.getElementsByTagName('iframe');
        var framesHtml = [];
        for (i = 0; i < frames.length; i++) {
            framesHtml.push(frames[i].contentWindow.document.documentElement.innerHTML);
        }
        framesHtml.forEach(function (item, index, array) {
            console.log(item);
        });

        sendMessage({ message: framesHtml});
        console.log("Sent iframes.\n");
    }
    else {
        console.log("Invalid request action.\n");
        sendMessage({}); // Send nothing..
    }
});