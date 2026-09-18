function ndiRefresh() {
    if (!root.document || root.document.fileType !== Document.Notebook) return;
    const notebook = String(root.document.id);
    Values.ndiRequest("query", {notebook: notebook, current: Values.ndiIds(root.document)}, function(result) {
        if (!root.document || String(root.document.id) !== notebook) return;
        ndiPopup.ready = !!result;
        if (result) { ndiPopup.tracking = result.enabled; ndiPopup.groups = result.groups; }
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
    modal: true
    focus: true
    width: Math.min(root.width - 40, 680)
    height: Math.min(root.height - 80, 860)
    x: (root.width - width) / 2
    y: (root.height - height) / 2
    padding: 24
    onOpened: { ready = false; groups = []; expandedDay = ""; root.ndiRefresh(); }
    background: Rectangle { color: "white"; border.color: "black"; border.width: 2; radius: 8 }
    contentItem: Column {
        spacing: 12
        NdiControls.Label { text: "Dates"; font.pixelSize: 32; font.bold: true; color: "black" }
        NdiControls.Label {
            width: parent.width
            text: "New pages, grouped by creation date. Existing pages stay undated. Stored only on this tablet."
            wrapMode: Text.WordWrap
            font.pixelSize: 21
            color: "black"
        }
        NdiControls.Button {
            width: parent.width
            text: ndiPopup.tracking ? "Tracking on — pause for this notebook" : "Enable for this notebook"
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
        NdiControls.Label {
            width: parent.width
            visible: text !== ""
            text: Values.ndiError || (ndiPopup.groups.length === 0 ? "No dated pages yet. Enable tracking, then add a new page." : "Tap a date to open its first page; + shows all pages.")
            wrapMode: Text.WordWrap
            font.pixelSize: 20
            color: "black"
        }
        ListView {
            width: parent.width
            height: Math.max(100, ndiPopup.availableHeight - 300)
            clip: true
            model: ndiPopup.groups
            spacing: 8
            delegate: Column {
                required property var modelData
                width: ListView.view.width
                Row {
                    width: parent.width
                    NdiControls.Button {
                        width: parent.width - 64
                        text: modelData.day + "  (" + modelData.pages.length + ")"
                        onClicked: {
                            let page = root.document.pageForId(modelData.pages[0].id);
                            if (page >= 0) { ndiPopup.close(); root.openPage(page); }
                        }
                    }
                    NdiControls.Button { width: 64; text: ndiPopup.expandedDay === modelData.day ? "−" : "+"; onClicked: ndiPopup.expandedDay = ndiPopup.expandedDay === modelData.day ? "" : modelData.day }
                }
                Repeater {
                    model: ndiPopup.expandedDay === modelData.day ? modelData.pages : []
                    NdiControls.Button {
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
        NdiControls.Button { width: parent.width; text: "Close"; onClicked: ndiPopup.close() }
    }
}
