component DatesButton: NdiControls.Button {
    id: button
    property bool primary: false
    implicitHeight: 64
    leftPadding: 18
    rightPadding: 18
    font.pixelSize: 24
    opacity: enabled ? 1 : 0.45
    background: Rectangle {
        radius: 6
        color: button.down ? "#d0d0d0" : (button.primary ? "black" : "white")
        border.width: 2
        border.color: "black"
    }
    contentItem: Text {
        text: button.text
        font: button.font
        color: button.primary && !button.down ? "white" : "black"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}

function ndiRefresh() {
    if (!root.document || root.document.fileType !== Document.Notebook) return;
    const notebook = String(root.document.id);
    Values.ndiRequest("query", {notebook: notebook, current: Values.ndiIds(root.document)}, function(result) {
        if (!root.document || String(root.document.id) !== notebook) return;
        ndiPopup.ready = !!result;
        if (result) { ndiPopup.tracking = result.enabled; ndiPopup.groups = result.groups; ndiPopup.timezone = result.timezone || "Asia/Jerusalem"; }
    });
}

Connections {
    target: Values
    function onNdiOpenRequested() {
        if (root.visible && root.document && root.document.fileType === Document.Notebook) {
            toolbar.closeFoldout();
            ndiPopup.open();
        }
    }
    function onNdiChanged(notebook) {
        if (ndiPopup.opened && root.document && String(root.document.id) === notebook) root.ndiRefresh();
    }
}

NdiControls.Popup {
    id: ndiPopup
    property bool ready: false
    property bool tracking: false
    property var groups: []
    property string expandedDay: ""
    property string timezone: "Asia/Jerusalem"
    property var timezoneOptions: ["Asia/Jerusalem", "UTC", "Europe/London", "America/New_York"].indexOf(timezone) >= 0
        ? ["Asia/Jerusalem", "UTC", "Europe/London", "America/New_York"]
        : [timezone, "Asia/Jerusalem", "UTC", "Europe/London", "America/New_York"]
    modal: true
    focus: true
    width: Math.min(root.width - 64, 760)
    height: Math.min(root.height - 100, 1000)
    x: (root.width - width) / 2
    y: (root.height - height) / 2
    padding: 32
    onOpened: { ready = false; groups = []; expandedDay = ""; root.ndiRefresh(); }
    background: Rectangle { color: "white"; border.color: "black"; border.width: 2; radius: 8 }
    contentItem: Column {
        spacing: 18
        NdiControls.Label { id: dateHeader; text: "Dates"; font.pixelSize: 32; font.bold: true; color: "black" }
        NdiControls.Label {
            id: dateIntro
            width: parent.width
            text: "Find your pages by the day you created them. Existing pages stay undated."
            wrapMode: Text.WordWrap
            font.pixelSize: 21
            color: "black"
        }
        DatesButton {
            id: trackingButton
            width: parent.width
            primary: !ndiPopup.tracking
            text: ndiPopup.tracking ? "Pause date tracking" : "Enable for this notebook"
            enabled: ndiPopup.ready
            onClicked: {
                if (!root.document) return;
                ndiPopup.ready = false;
                const notebook = String(root.document.id);
                Values.ndiRequest("toggle", {notebook: notebook, current: Values.ndiIds(root.document), enabled: !ndiPopup.tracking}, function(result) {
                    if (root.document && String(root.document.id) === notebook) root.ndiRefresh();
                });
            }
        }
        Column {
            id: timezoneControls
            width: parent.width
            spacing: 10
            NdiControls.Label { text: "Timezone for new pages"; font.pixelSize: 22; color: "black" }
            NdiControls.ComboBox {
                id: timezonePicker
                width: parent.width
                height: 64
                font.pixelSize: 24
                leftPadding: 18
                rightPadding: 50
                opacity: enabled ? 1 : 0.45
                background: Rectangle { color: "white"; border.color: "black"; border.width: 2; radius: 6 }
                contentItem: Text { text: timezonePicker.displayText; font: timezonePicker.font; color: "black"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                indicator: Text { text: "⌄"; font.pixelSize: 28; color: "black"; x: parent.width - width - 18; anchors.verticalCenter: parent.verticalCenter }
                delegate: NdiControls.ItemDelegate {
                    required property string modelData
                    required property int index
                    width: timezonePicker.width
                    height: 64
                    contentItem: Text { text: modelData; font.pixelSize: 24; color: "black"; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.highlighted ? "#dedede" : "white" }
                    highlighted: timezonePicker.highlightedIndex === index
                }
                popup.background: Rectangle { color: "white"; border.color: "black"; border.width: 2 }
                model: ndiPopup.timezoneOptions
                currentIndex: ndiPopup.timezoneOptions.indexOf(ndiPopup.timezone)
                enabled: ndiPopup.ready
                onActivated: {
                    ndiPopup.ready = false;
                    Values.ndiRequest("settings", {timezone: currentText}, function(result) { root.ndiRefresh(); });
                }
            }
        }
        NdiControls.Label {
            id: dateStatus
            width: parent.width
            visible: text !== ""
            text: Values.ndiError || (ndiPopup.groups.length === 0
                ? (ndiPopup.tracking ? "Tracking is on. Add a page, then come back here.\nDates are currently saved on this tablet." : "Tracking is off for this notebook.\nTurn it on to date new pages.")
                : (ndiPopup.tracking ? "Tracking on. " : "Tracking paused. ") + "Tap a date to open it; + shows its pages.")
            wrapMode: Text.WordWrap
            font.pixelSize: 20
            color: "black"
        }
        ListView {
            width: parent.width
            height: Math.max(60, ndiPopup.availableHeight - dateHeader.height - dateIntro.height - trackingButton.height - timezoneControls.height - dateStatus.height - closeDatesButton.height - 6 * parent.spacing)
            clip: true
            model: ndiPopup.groups
            spacing: 8
            delegate: Column {
                required property var modelData
                width: ListView.view.width
                Row {
                    width: parent.width
                    spacing: 8
                    DatesButton {
                        width: parent.width - 72
                        text: modelData.day + "  (" + modelData.pages.length + ")"
                        onClicked: {
                            let page = root.document.pageForId(modelData.pages[0].id);
                            if (page >= 0) { ndiPopup.close(); root.openPage(page); }
                        }
                    }
                    DatesButton { width: 64; text: ndiPopup.expandedDay === modelData.day ? "−" : "+"; onClicked: ndiPopup.expandedDay = ndiPopup.expandedDay === modelData.day ? "" : modelData.day }
                }
                Repeater {
                    model: ndiPopup.expandedDay === modelData.day ? modelData.pages : []
                    DatesButton {
                        required property var modelData
                        width: parent.width
                        text: "Page " + modelData.number
                        onClicked: {
                            let page = root.document.pageForId(modelData.id);
                            if (page >= 0) { ndiPopup.close(); root.openPage(page); }
                        }
                    }
                }
            }
        }
        DatesButton { id: closeDatesButton; width: parent.width; text: "Done"; onClicked: ndiPopup.close() }
    }
}
