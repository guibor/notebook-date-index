property string ndiToken: ""
property var ndiQueue: []
property bool ndiBusy: false
property var ndiEnabled: ({})
property string ndiError: ""
signal ndiOpenRequested()
signal ndiChanged(string notebook)

function ndiIds(doc) {
    if (!doc || doc.fileType !== Document.Notebook || doc.pageCount > 20000) return [];
    let result = [];
    for (let i = 0; i < doc.pageCount; ++i) result.push(String(doc.idForPage(i)));
    return result;
}

function ndiRequest(action, body, done) {
    if (ndiQueue.length >= 64) {
        ndiError = "Dates queue full; this event was not saved.";
        if (done) done(null);
        return;
    }
    ndiQueue.push({action: action, body: body, done: done});
    ndiPump();
}

function ndiPump() {
    if (ndiBusy || ndiQueue.length === 0) return;
    ndiBusy = true;
    if (!ndiToken) {
        let key = new XMLHttpRequest();
        key.open("GET", "file:///home/root/.local/share/notebook-date-index/token");
        key.onreadystatechange = function() {
            if (key.readyState !== XMLHttpRequest.DONE) return;
            ndiToken = key.responseText.trim();
            ndiBusy = false;
            if (ndiToken.length !== 64) {
                ndiError = "Dates service is not running. Reconnect from the computer.";
                let failed = ndiQueue.splice(0);
                failed.forEach(function(job) { if (job.done) job.done(null); });
                return;
            }
            ndiPump();
        };
        key.send();
        return;
    }
    let job = ndiQueue[0];
    let req = new XMLHttpRequest();
    req.open("POST", "http://127.0.0.1:18742/v1/" + job.action);
    req.setRequestHeader("Content-Type", "application/json");
    req.setRequestHeader("X-Date-Index-Token", ndiToken);
    req.onreadystatechange = function() {
        if (req.readyState !== XMLHttpRequest.DONE) return;
        let result = null;
        if (req.status === 200) {
            try { result = JSON.parse(req.responseText); } catch (e) {}
        }
        ndiError = result ? "" : "Dates could not be saved or loaded. Your notebook is unchanged. Reopen Dates to retry.";
        if (result && job.body.notebook) {
            ndiEnabled[job.body.notebook] = result.enabled;
        }
        ndiQueue.shift();
        ndiBusy = false;
        if (job.done) job.done(result);
        if (result && job.body.notebook && job.action !== "query") ndiChanged(job.body.notebook);
        ndiPump();
    };
    req.send(JSON.stringify(job.body));
}

function ndiBegin(doc, count, source) {
    try {
        if (!doc || doc.fileType !== Document.Notebook || doc.pageCount > 20000) return null;
        let now = new Date();
        return {notebook: String(doc.id), before: ndiIds(doc), count: count,
                source: source, utc: now.toISOString(), offset: -now.getTimezoneOffset(), started: now.getTime()};
    } catch (e) { ndiError = "Dates could not observe this page."; return null; }
}

function ndiFinish(doc, ticket, eventIndexes) {
    try {
        if (!ticket || !doc || String(doc.id) !== ticket.notebook || Date.now() - ticket.started > 10000) return;
        // Firmware may report a batch through one signal or several single-page signals.
        if (eventIndexes) {
            if (!ticket.signaled) ticket.signaled = [];
            eventIndexes.forEach(function(i) {
                let id = String(doc.idForPage(i));
                if (ticket.signaled.indexOf(id) < 0) ticket.signaled.push(id);
            });
        }
        let current = ndiIds(doc);
        let created = current.filter(function(id) { return ticket.before.indexOf(id) < 0; });
        if (created.length !== ticket.count) return;
        if (eventIndexes) {
            let signaled = ticket.signaled;
            if (signaled.length !== created.length || created.some(function(id) { return signaled.indexOf(id) < 0; })) return;
        }
        let completed = new Date();
        ndiRequest("record", {notebook: ticket.notebook, before: ticket.before,
            current: current, created: created, utc: completed.toISOString(), offset: -completed.getTimezoneOffset(), source: ticket.source}, null);
        return true;
    } catch (e) { ndiError = "Dates could not save this page's date."; }
}

// Keep stock operations and callbacks independent of our optional recorder.
function ndiAddPage(controller, doc, index, template, size, callback) {
    // Native singletons belong to the caller's imports, not Values' imports.
    // Never resolve DocumentController from this singleton's lexical scope.
    let ticket = null;
    try { ticket = ndiBegin(doc, 1, "add"); } catch (e) {}
    return controller.addPageWithTemplateAndPageSize(doc.id, index, template, size, function() {
        try {
            if (callback) callback.apply(this, arguments);
        } finally {
            // The stock callback has priority, including when observation fails.
            try { ndiFinish(doc, ticket, null); } catch (e) {}
        }
    });
}
