pragma Singleton

import QtQuick

// Stub for Requests - HTTP request utility
QtObject {
    id: root

    function get(url, onSuccess, onError) {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    if (onSuccess) onSuccess(xhr.responseText);
                } else {
                    console.warn("Requests.get failed:", url, xhr.status, xhr.statusText);
                    if (onError) onError(xhr.statusText);
                }
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }
}
