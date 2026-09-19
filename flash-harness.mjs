// Exercise the real popup with genuinely delayed, explicitly completed requests.
// Run after generation with QT_QUICK_CONTROLS_STYLE=Basic QT_QPA_PLATFORM=offscreen
// QT_QUICK_BACKEND=software qml --disable-context-sharing build/flash-harness.qml.
import fs from 'node:fs';

const resources = process.cwd() + '/../remarkable-beta-os/.cache/firmware/3.28.0.169/resources';
const popup = fs.readFileSync('qml/popup.qml.inc', 'utf8')
  .replaceAll('Values.', 'bridge.')
  .replaceAll('target: Values', 'target: bridge')
  .replaceAll('Document.Notebook', '1')
  .replaceAll('qrc:/ark/icons/', 'file://' + resources + '/ark/icons/');
fs.mkdirSync('build', {recursive: true});
fs.copyFileSync('qml/date-tree.js', 'build/DateTree.js');

const harness = `import QtQuick
import QtQuick.Controls 2.15 as NdiControls
import "DateTree.js" as DateTree
Rectangle {
    id: root
    width: ${Number(process.env.NDI_UI_WIDTH || 1000)}
    height: ${Number(process.env.NDI_UI_HEIGHT || 1400)}
    color: "white"
    property var document: makeDocument("notebook-a")
    property var savedGroups: null
    property bool watchWarm: false
    property bool failed: false
    property int step: 0
    function makeDocument(id) {
        return {id:id, fileType:1, pageForId:function(id) { return 0; }};
    }
    function openPage(page) { fail("Flash harness must not navigate native pages"); }
    function fail(message) {
        if (failed) return;
        failed = true;
        console.error("Dates flash runtime FAILED at step " + step + ": " + message);
        Qt.exit(1);
    }
    function check(condition, message) { if (!condition) fail(message); }
    function hasVisibleText(item, text) {
        if (!item || !item.visible) return false;
        if (typeof item.text === "string" && item.text.indexOf(text) >= 0) return true;
        if (!item.children) return false;
        for (let i=0; i<item.children.length; i++) {
            if (hasVisibleText(item.children[i], text)) return true;
        }
        return false;
    }
    function checkErrorVisible() {
        check(ndiPopup.refreshError.length > 0, "Failure needs an explicit refresh error");
        check(hasVisibleText(ndiPopup.contentItem, ndiPopup.refreshError), "Refresh error is not visibly rendered");
    }
    QtObject { id: toolbar; function closeFoldout() {} }
    QtObject {
        id: bridge
        property string ndiError: ""
        property bool enabled: true
        property string zone: "Asia/Jerusalem"
        property var pending: []
        signal ndiOpenRequested()
        signal ndiChanged(string notebook)
        function ndiIds(doc) { return ["one", "two"]; }
        function ndiRequest(action, body, done) {
            // Mutations here only update these in-memory mock properties.
            root.check(["query", "toggle", "settings"].indexOf(action) >= 0, "Unexpected request action");
            pending.push({action:action, body:body, done:done});
        }
        function result(body) {
            return {
                enabled:enabled, timezone:zone, mode:body.mode,
                undated:0, estimated:0, sync:"Up to date",
                groups:[{day:body.mode === "modified" ? "2026-09-19" : "2026-09-18",
                    pages:[{id:body.notebook + "-one", number:2}, {id:body.notebook + "-two", number:5}]}]
            };
        }
        function complete(index, success) {
            root.check(index >= 0 && index < pending.length, "Missing delayed request");
            if (root.failed) return;
            const job = pending.splice(index, 1)[0];
            ndiError = success ? "" : "Test connection unavailable";
            if (success && job.action === "toggle") enabled = job.body.enabled;
            if (success && job.action === "settings") zone = job.body.timezone;
            const response = job.action === "query" ? result(job.body) : {enabled:enabled, timezone:zone};
            job.done(success ? response : null);
        }
    }
    ${popup}
    Connections {
        target: ndiPopup
        function onReadyChanged() {
            if (root.watchWarm && !ndiPopup.ready) root.fail("Warm refresh cleared ready");
        }
        function onGroupsChanged() {
            if (root.watchWarm && ndiPopup.groups.length === 0) root.fail("Warm refresh cleared dates");
        }
    }
    Connections {
        target: dateList
        function onVisibleChanged() {
            if (root.watchWarm && dateList.visible) root.fail("Warm Calendar refresh briefly displayed List");
        }
    }
    Connections {
        target: calendarMonthView
        function onVisibleChanged() {
            if (root.watchWarm && ndiPopup.opened && !calendarMonthView.visible) root.fail("Warm Calendar refresh hid the month");
        }
    }
    Timer {
        interval:100; repeat:true; running:true
        onTriggered: {
            if (root.failed) return;
            switch (root.step) {
            case 0:
                // This is the same preload used by the real document's Loader.
                root.ndiRefresh();
                root.check(bridge.pending.length === 1 && !ndiPopup.ready, "Preload did not remain asynchronous");
                break;
            case 1:
                bridge.complete(0, true);
                root.savedGroups = ndiPopup.groups;
                root.check(ndiPopup.ready && ndiPopup.scopeKey === "notebook-a|created", "Preload scope mismatch");
                ndiPopup.switchPresentation("calendar");
                root.watchWarm = true;
                ndiPopup.open();
                root.check(bridge.pending.length === 1, "Opening must refresh via onAboutToShow");
                break;
            case 2:
                root.check(ndiPopup.opened && calendarMonthView.visible && !dateList.visible, "Warm open did not retain Calendar");
                root.check(ndiPopup.ready && ndiPopup.groups === root.savedGroups, "Warm open lost cached model");
                root.check(!ndiPopup.dim, "Popup dims the notebook background");
                bridge.complete(0, true);
                root.check(ndiPopup.groups === root.savedGroups, "Equal response rebuilt the date model");
                root.watchWarm = false;
                ndiPopup.close();
                break;
            case 3:
                root.check(!ndiPopup.visible, "Popup failed to close without a transition");
                root.watchWarm = true;
                ndiPopup.open();
                break;
            case 4:
                root.check(ndiPopup.opened && calendarMonthView.visible && !dateList.visible, "Reopen flashed the alternate layout");
                root.check(ndiPopup.ready && ndiPopup.groups === root.savedGroups, "Reopen lost cached data");
                bridge.complete(0, false);
                root.check(ndiPopup.ready && ndiPopup.groups === root.savedGroups && calendarMonthView.visible, "Refresh failure hid cached dates");
                root.checkErrorVisible();
                root.watchWarm = false;
                ndiPopup.close();
                break;
            case 5:
                root.document = root.makeDocument("notebook-b");
                ndiPopup.open();
                root.check(!ndiPopup.ready && ndiPopup.groups.length === 0, "Other notebook displayed old cached dates");
                root.check(ndiPopup.scopeKey === "notebook-b|created", "Notebook scope did not change before showing");
                root.check(!calendarMonthView.visible && !dateList.visible, "Cold query showed a stale content view");
                break;
            case 6:
                bridge.complete(0, false);
                root.check(!ndiPopup.ready && ndiPopup.groups.length === 0, "Cold failure fabricated ready data");
                root.checkErrorVisible();
                root.ndiRefresh();
                break;
            case 7:
                bridge.complete(0, true);
                root.check(ndiPopup.ready && ndiPopup.refreshError === "", "Successful retry did not recover");
                root.check(ndiPopup.groups[0].pages[0].id === "notebook-b-one", "Retry crossed notebook identities");
                // Queue one Created request, then a newer Modified request.
                root.ndiRefresh();
                ndiPopup.switchMode("modified");
                root.check(bridge.pending.length === 2 && !ndiPopup.ready && ndiPopup.groups.length === 0, "Mode change retained mismatched cache");
                break;
            case 8:
                bridge.complete(0, true);
                root.check(!ndiPopup.ready && ndiPopup.groups.length === 0 && ndiPopup.scopeKey === "notebook-b|modified", "Stale Created response overwrote Modified scope");
                break;
            case 9:
                bridge.complete(0, true);
                root.check(ndiPopup.ready && ndiPopup.groups[0].day === "2026-09-19", "Latest Modified query did not apply");
                root.savedGroups = ndiPopup.groups;
                // Same-scope generation guard: newer success beats older failure.
                root.ndiRefresh(); root.ndiRefresh();
                break;
            case 10:
                bridge.complete(1, true);
                bridge.complete(0, false);
                root.check(ndiPopup.ready && ndiPopup.groups === root.savedGroups && ndiPopup.refreshError === "", "Stale failure overwrote newer success");
                // A pending query for B must never update a newly selected C.
                root.ndiRefresh();
                root.document = root.makeDocument("notebook-c");
                root.ndiRefresh();
                break;
            case 11:
                bridge.complete(0, true);
                root.check(!ndiPopup.ready && ndiPopup.groups.length === 0 && ndiPopup.scopeKey === "notebook-c|modified", "Stale notebook response leaked across documents");
                break;
            case 12:
                bridge.complete(0, true);
                root.check(ndiPopup.ready && ndiPopup.groups[0].pages[0].id === "notebook-c-one", "Current notebook response was lost");
                root.check(bridge.pending.length === 0, "Harness left pending queries");
                root.savedGroups = ndiPopup.groups;
                settingsButton.clicked();
                timezonePicker.currentIndex = ndiPopup.timezoneOptions.indexOf("UTC");
                timezonePicker.activated(timezonePicker.currentIndex);
                root.check(ndiPopup.ready && ndiPopup.settingsBusy && !timezonePicker.enabled && !trackingButton.enabled, "Timezone write cleared cache or left controls enabled while busy");
                root.check(bridge.pending.length === 1 && bridge.pending[0].action === "settings", "Timezone write was not queued");
                break;
            case 13:
                bridge.complete(0, true);
                root.check(ndiPopup.ready && !ndiPopup.settingsBusy && timezonePicker.enabled && trackingButton.enabled, "Confirmed timezone write failed to release settings controls");
                root.check(ndiPopup.timezone === "UTC", "Confirmed timezone was not reflected before query refresh");
                root.check(bridge.pending.length === 1 && bridge.pending[0].action === "query", "Timezone success did not refresh data");
                break;
            case 14:
                bridge.complete(0, false);
                root.check(ndiPopup.ready && ndiPopup.groups === root.savedGroups && !ndiPopup.settingsBusy, "Failed query after timezone write hid cached dates");
                root.check(timezonePicker.enabled && trackingButton.enabled, "Failed settings refresh stranded disabled controls");
                root.checkErrorVisible();
                trackingButton.clicked();
                root.check(ndiPopup.ready && ndiPopup.settingsBusy && !trackingButton.enabled && !timezonePicker.enabled, "Tracking mutation cleared cached data or did not guard controls");
                root.check(bridge.pending.length === 1 && bridge.pending[0].action === "toggle", "Tracking mutation was not queued");
                break;
            case 15:
                bridge.complete(0, true);
                root.check(ndiPopup.ready && !ndiPopup.settingsBusy && !ndiPopup.showSettings, "Confirmed tracking update hid cache or retained busy state");
                root.check(!ndiPopup.tracking && !bridge.enabled, "Confirmed tracking state was not applied before refresh");
                root.check(bridge.pending.length === 1 && bridge.pending[0].action === "query", "Tracking success did not refresh data");
                break;
            case 16:
                bridge.complete(0, false);
                root.check(ndiPopup.ready && ndiPopup.groups === root.savedGroups && calendarMonthView.visible, "Failed query after tracking update hid Calendar history");
                root.check(!ndiPopup.settingsBusy && trackingButton.enabled && timezonePicker.enabled, "Failed tracking refresh stranded disabled controls");
                root.checkErrorVisible();
                root.check(bridge.pending.length === 0, "Harness left pending settings requests");
                console.log("Dates flash runtime PASSED");
                Qt.quit();
                return;
            }
            root.step++;
        }
    }
    Timer { interval:10000; running:true; onTriggered:root.fail("Timed out") }
}
`;
fs.writeFileSync('build/flash-harness.qml', harness);
