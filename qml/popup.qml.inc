component DatesButton: NdiControls.Button {
    id: button
    property bool primary: false
    property bool quiet: false
    implicitHeight: 64
    leftPadding: 20; rightPadding: 20
    font.pixelSize: 25
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        radius: 8
        color: button.down ? "#d8d8d8" : (button.primary ? "black" : "white")
        border.width: button.quiet ? 0 : 1
        border.color: "#777777"
    }
    contentItem: Text {
        text: button.text; font: button.font
        color: button.primary && !button.down ? "white" : "black"
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}

function ndiRefresh() {
    if (!root.document || root.document.fileType !== Document.Notebook) return;
    const notebook = String(root.document.id);
    const mode = ndiPopup.mode;
    const generation = ++ndiPopup.requestGeneration;
    Values.ndiRequest("query", {notebook:notebook, current:Values.ndiIds(root.document), mode:mode}, function(result) {
        if (!root.document || String(root.document.id) !== notebook || generation !== ndiPopup.requestGeneration || mode !== ndiPopup.mode) return;
        ndiPopup.ready = !!result;
        if (result) {
            ndiPopup.tracking = result.enabled; ndiPopup.groups = result.groups;
            ndiPopup.timezone = result.timezone || "Asia/Jerusalem";
            ndiPopup.undated = result.undated || 0; ndiPopup.estimates = result.estimated || 0;
            ndiPopup.warning = result.warning || "";
            ndiPopup.syncStatus = result.sync || "Local only · sync not configured";
        }
    });
}

Connections {
    target: Values
    function onNdiOpenRequested() {
        if (root.visible && root.document && root.document.fileType === Document.Notebook) {
            toolbar.closeFoldout(); ndiPopup.open();
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
    property bool showSettings: false
    property bool initializeOlder: false
    property var groups: []
    property var expanded: ({})
    property var dateRows: DateTree.rows(groups, expanded)
    property string mode: "created"
    property string presentation: "list"
    property string selectedDay: ""
    property var byDay: DateTree.dayGroups(groups)
    property var calendarInfo: DateTree.calendarRange(groups)
    property var selectedPages: byDay[selectedDay] ? byDay[selectedDay].pages : []
    property int requestGeneration: 0
    property int undated: 0
    property int estimates: 0
    property string warning: ""
    property string syncStatus: ""
    property string timezone: "Asia/Jerusalem"
    property var timezoneOptions: ["Asia/Jerusalem", "UTC", "Europe/London", "Europe/Paris", "America/New_York", "America/Los_Angeles", "Asia/Tokyo"].indexOf(timezone) >= 0
        ? ["Asia/Jerusalem", "UTC", "Europe/London", "Europe/Paris", "America/New_York", "America/Los_Angeles", "Asia/Tokyo"]
        : [timezone, "Asia/Jerusalem", "UTC", "Europe/London", "Europe/Paris", "America/New_York", "America/Los_Angeles", "Asia/Tokyo"]
    function switchMode(next) {
        if (mode === next) return;
        mode = next; groups = []; expanded = ({}); selectedDay = ""; warning = ""; ready = false;
        root.ndiRefresh();
    }
    function switchPresentation(next) {
        presentation = next; selectedDay = "";
    }
    function selectDay(day) {
        if (byDay[day] && byDay[day].pages.length) selectedDay = day;
    }
    function expandRow(row) {
        const next = Object.assign({}, expanded);
        next[row.key] = !row.expanded; expanded = next;
    }
    function jump(id) {
        if (!root.document || !id) return;
        const page = root.document.pageForId(id);
        if (page >= 0) { close(); root.openPage(page); }
    }
    modal: true; focus: true
    width: Math.min(root.width - 64, 900); height: Math.min(root.height - 100, 1200)
    x: (root.width - width) / 2; y: (root.height - height) / 2
    padding: 32
    onOpened: {
        ready = false; groups = []; expanded = ({}); selectedDay = ""; showSettings = false;
        initializeOlder = false; warning = ""; root.ndiRefresh();
    }
    background: Rectangle { color:"white"; border.color:"black"; border.width:2; radius:14 }
    contentItem: Item {
        Item {
            id: header
            width: parent.width; height: 64
            DatesButton { id: backButton; visible:ndiPopup.showSettings; width:64; text:"‹"; font.pixelSize:40; quiet:true; onClicked:ndiPopup.showSettings=false }
            Text {
                x: ndiPopup.showSettings ? 72 : 0
                width: parent.width - x - (ndiPopup.showSettings ? 72 : 144)
                height:64; text:ndiPopup.showSettings ? "Dates settings" : "Dates"
                font.pixelSize:36; font.bold:true; color:"black"; verticalAlignment:Text.AlignVCenter; elide:Text.ElideRight
            }
            DatesButton {
                id: settingsButton; x:parent.width-136; width:64; quiet:true; visible:!ndiPopup.showSettings
                contentItem: Image { source:"qrc:/ark/icons/cog"; sourceSize:Qt.size(30,30); fillMode:Image.PreserveAspectFit }
                onClicked:ndiPopup.showSettings=true
            }
            DatesButton { id: closeDatesButton; x:parent.width-64; width:64; text:"×"; font.pixelSize:36; quiet:true; onClicked:ndiPopup.close() }
        }
        Item {
            id: datesView; visible:!ndiPopup.showSettings
            anchors { top:header.bottom; topMargin:22; left:parent.left; right:parent.right; bottom:parent.bottom }
            Rectangle {
                id: viewTabs; width:parent.width; height:70; radius:10; color:"#eeeeee"
                Row {
                    anchors.fill:parent; anchors.margins:3; spacing:4
                    DatesButton { id: createdTab; width:(parent.width-4)/2; height:64; text:"Created"; primary:ndiPopup.mode==="created"; quiet:true; onClicked:ndiPopup.switchMode("created") }
                    DatesButton { id: modifiedTab; width:(parent.width-4)/2; height:64; text:"Modified"; primary:ndiPopup.mode==="modified"; quiet:true; onClicked:ndiPopup.switchMode("modified") }
                }
            }
            Text {
                id: viewCaption; anchors { top:viewTabs.bottom; topMargin:16; left:parent.left; right:parent.right }
                text:ndiPopup.mode === "modified" ? "Last edited · from notebook metadata" : "Creation dates · tracking " + (ndiPopup.tracking ? "on" : "paused")
                font.pixelSize:21; color:"#555555"; wrapMode:Text.WordWrap
            }
            Row {
                id: layoutTabs
                anchors { top:viewCaption.bottom; topMargin:16; left:parent.left; right:parent.right }
                height:64; spacing:8
                DatesButton { id:listTab; width:(parent.width-8)/2; height:64; text:"List"; primary:ndiPopup.presentation==="list"; onClicked:ndiPopup.switchPresentation("list") }
                DatesButton { id:calendarTab; width:(parent.width-8)/2; height:64; text:"Calendar"; primary:ndiPopup.presentation==="calendar"; onClicked:ndiPopup.switchPresentation("calendar") }
            }
            ListView {
                id: dateList
                visible:ndiPopup.presentation==="list" || !ndiPopup.ready
                anchors { top:layoutTabs.bottom; topMargin:18; left:parent.left; right:parent.right; bottom:dateFooter.top; bottomMargin:14 }
                clip:true; model:ndiPopup.dateRows
                boundsBehavior:Flickable.StopAtBounds
                NdiControls.ScrollBar.vertical: NdiControls.ScrollBar { width:6; policy:NdiControls.ScrollBar.AsNeeded }
                delegate: Item {
                    id: dateRow
                    required property var modelData
                    width:ListView.view.width; height:modelData.kind === "year" ? 86 : 82
                    Rectangle { anchors.fill:parent; radius:6; color:rowTap.pressed ? "#dedede" : (modelData.kind === "year" ? "#eeeeee" : "white") }
                    Rectangle { anchors { bottom:parent.bottom; left:parent.left; right:parent.right; leftMargin:modelData.depth*22+12 } height:1; color:"#dddddd"; visible:modelData.kind!=="page" }
                    Column {
                        x:modelData.depth*22+14; anchors.verticalCenter:parent.verticalCenter
                        width:parent.width-x-72; spacing:5
                        Text { width:parent.width; text:modelData.title; color:"black"; font.pixelSize:modelData.kind==="year" ? 30 : 25; font.bold:modelData.kind==="year" || modelData.kind==="month"; elide:Text.ElideRight }
                        Text { width:parent.width; visible:text!==""; text:modelData.detail; font.pixelSize:19; color:"#555555"; elide:Text.ElideRight }
                    }
                    MouseArea {
                        id:rowTap; anchors.fill:parent; anchors.rightMargin:modelData.kind==="page" ? 0 : 66
                        onClicked: { if (modelData.kind==="day" || modelData.kind==="page") ndiPopup.jump(modelData.pageId); else ndiPopup.expandRow(modelData); }
                    }
                    DatesButton {
                        anchors { right:parent.right; verticalCenter:parent.verticalCenter } width:64; height:64; quiet:true
                        visible:modelData.kind!=="page"; text:modelData.expanded ? "−" : "+"; font.pixelSize:30
                        onClicked:ndiPopup.expandRow(modelData)
                    }
                }
                Column {
                    anchors.centerIn:parent; width:parent.width-36; spacing:18
                    visible:ndiPopup.groups.length===0
                    Text {
                        width:parent.width; horizontalAlignment:Text.AlignHCenter; wrapMode:Text.WordWrap
                        text:!ndiPopup.ready ? (Values.ndiError ? "Dates unavailable" : "Loading dates…") : (ndiPopup.mode==="modified" ? "No saved modification dates" : "Your page history starts here")
                        font.pixelSize:28; font.bold:true; color:"black"
                    }
                    Text {
                        width:parent.width; horizontalAlignment:Text.AlignHCenter; wrapMode:Text.WordWrap
                        text:Values.ndiError || ndiPopup.warning || (ndiPopup.mode==="modified" ? "Dates appear here when the notebook saves a page’s last edit." : (ndiPopup.tracking ? "Add a page and its creation date will appear here." : "Turn on tracking in settings to remember new pages. You can also include older pages using estimated dates."))
                        font.pixelSize:22; color:"#555555"
                    }
                    DatesButton {
                        anchors.horizontalCenter:parent.horizontalCenter; width:Math.min(parent.width,360)
                        visible:ndiPopup.ready && ndiPopup.mode==="created" && !ndiPopup.tracking
                        text:"Set up tracking"; primary:true; onClicked:ndiPopup.showSettings=true
                    }
                }
            }
            ListView {
                id:calendarList
                visible:ndiPopup.ready && ndiPopup.presentation==="calendar" && ndiPopup.selectedDay===""
                anchors { top:layoutTabs.bottom; topMargin:18; left:parent.left; right:parent.right; bottom:dateFooter.top; bottomMargin:14 }
                clip:true; boundsBehavior:Flickable.StopAtBounds
                model:ndiPopup.calendarInfo.count
                spacing:24
                NdiControls.ScrollBar.vertical:NdiControls.ScrollBar { width:6; policy:NdiControls.ScrollBar.AsNeeded }
                delegate:Item {
                    id:monthCard
                    required property int index
                    property var monthData:DateTree.calendarMonth(ndiPopup.calendarInfo.latest-index,ndiPopup.byDay)
                    width:ListView.view.width; height:526
                    Text { id:monthHeading; width:parent.width; height:52; text:monthCard.monthData.title; font.pixelSize:29; font.bold:true; color:"black"; verticalAlignment:Text.AlignVCenter }
                    Text { anchors { top:monthHeading.bottom; left:parent.left } text:monthCard.monthData.pages ? DateTree.pageCount(monthCard.monthData.pages) : "No dated pages"; font.pixelSize:20; color:"#555555" }
                    Row {
                        id:weekHeader; y:86; width:parent.width; height:32
                        Repeater {
                            model:["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                            Text { required property string modelData; width:weekHeader.width/7; height:32; text:modelData; font.pixelSize:19; color:"#555555"; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter }
                        }
                    }
                    Grid {
                        id:monthGrid; y:124; width:parent.width; columns:7
                        Repeater {
                            model:monthCard.monthData.cells
                            Item {
                                required property var modelData
                                width:monthGrid.width/7; height:66
                                Rectangle { anchors { fill:parent; margins:3 } radius:8; color:dayTap.pressed ? "#dedede" : "white" }
                                Text { anchors { top:parent.top; topMargin:7; horizontalCenter:parent.horizontalCenter } text:modelData.number || ""; font.pixelSize:25; font.bold:modelData.count>0; color:modelData.count ? "black" : "#777777" }
                                Rectangle { anchors { bottom:parent.bottom; bottomMargin:9; horizontalCenter:parent.horizontalCenter } width:7; height:7; radius:4; color:"black"; visible:modelData.count>0 }
                                MouseArea { id:dayTap; anchors.fill:parent; enabled:modelData.count>0; onClicked:ndiPopup.selectDay(modelData.day) }
                            }
                        }
                    }
                    Rectangle { anchors { bottom:parent.bottom; left:parent.left; right:parent.right } height:1; color:"#dddddd" }
                }
            }
            Item {
                id:calendarDay
                visible:ndiPopup.ready && ndiPopup.presentation==="calendar" && ndiPopup.selectedDay!==""
                anchors { top:layoutTabs.bottom; topMargin:18; left:parent.left; right:parent.right; bottom:dateFooter.top; bottomMargin:14 }
                DatesButton { id:calendarBack; width:parent.width; height:64; text:"‹  Back to months"; quiet:true; onClicked:ndiPopup.selectedDay="" }
                Text { id:dayHeading; anchors { top:calendarBack.bottom; topMargin:12; left:parent.left; right:parent.right } text:ndiPopup.selectedDay ? DateTree.dayTitle(ndiPopup.selectedDay) : ""; font.pixelSize:29; font.bold:true; wrapMode:Text.WordWrap; color:"black" }
                ListView {
                    id:dayPages
                    anchors { top:dayHeading.bottom; topMargin:12; left:parent.left; right:parent.right; bottom:parent.bottom }
                    model:ndiPopup.selectedPages; clip:true; boundsBehavior:Flickable.StopAtBounds
                    NdiControls.ScrollBar.vertical:NdiControls.ScrollBar { width:6; policy:NdiControls.ScrollBar.AsNeeded }
                    delegate:DatesButton {
                        required property var modelData
                        width:ListView.view.width; height:82; quiet:true
                        text:"Page "+modelData.number+(modelData.estimated ? " · estimated" : "")
                        onClicked:ndiPopup.jump(modelData.id)
                    }
                }
            }
            Text {
                id:dateFooter; anchors { bottom:parent.bottom; left:parent.left; right:parent.right }
                font.pixelSize:18; color:"#555555"; wrapMode:Text.WordWrap
                text:(ndiPopup.presentation==="calendar" ? (ndiPopup.selectedDay ? "Choose a page to open it." : "Scroll through months. Tap a marked day to see its pages.") : (ndiPopup.groups.length ? "Tap a day to open its first page. + shows all pages." : ""))+(ndiPopup.undated ? "\n"+ndiPopup.undated+(ndiPopup.undated===1 ? " page has" : " pages have")+" no "+(ndiPopup.mode==="created" ? "creation" : "modification")+" date." : "")+(ndiPopup.estimates ? "\nEstimated dates came from last modified, not observed creation." : "")
            }
        }
        Flickable {
            id:settingsView; visible:ndiPopup.showSettings
            anchors { top:header.bottom; topMargin:22; left:parent.left; right:parent.right; bottom:parent.bottom }
            contentHeight:settingsColumn.height; clip:true; boundsBehavior:Flickable.StopAtBounds
            NdiControls.ScrollBar.vertical: NdiControls.ScrollBar { width:6; policy:NdiControls.ScrollBar.AsNeeded }
            Column {
                id:settingsColumn; width:parent.width; spacing:22
                Text { text:"THIS NOTEBOOK"; font.pixelSize:18; font.letterSpacing:2; color:"#555555" }
                Text { width:parent.width; text:ndiPopup.tracking ? "Creation tracking is on" : "Creation tracking is paused"; font.pixelSize:27; font.bold:true; color:"black"; wrapMode:Text.WordWrap }
                Text { width:parent.width; text:"New pages keep the day they were created. Pausing keeps your existing history. Modified view is always available."; font.pixelSize:22; color:"#555555"; wrapMode:Text.WordWrap }
                NdiControls.CheckBox {
                    id:initializeCheck; width:parent.width; implicitHeight:86; visible:!ndiPopup.tracking
                    checked:ndiPopup.initializeOlder; enabled:ndiPopup.ready
                    onToggled:ndiPopup.initializeOlder=checked
                    indicator:Rectangle {
                        x:0; y:(parent.height-height)/2; width:32; height:32; radius:5; color:initializeCheck.checked ? "black" : "white"; border.color:"black"; border.width:2
                        Text { anchors.centerIn:parent; text:initializeCheck.checked ? "✓" : ""; font.pixelSize:26; color:"white" }
                    }
                    contentItem:Text { leftPadding:48; text:"Include undated pages using\nlast-modified dates (estimates)"; font.pixelSize:23; color:"black"; verticalAlignment:Text.AlignVCenter; wrapMode:Text.WordWrap }
                }
                Text {
                    width:parent.width; visible:!ndiPopup.tracking && ndiPopup.initializeOlder
                    text:"One-time snapshot when enabled. Existing creation dates stay unchanged. Pages without a saved modification date remain undated."
                    font.pixelSize:20; color:"#555555"; wrapMode:Text.WordWrap
                }
                DatesButton {
                    id:trackingButton; width:parent.width; primary:!ndiPopup.tracking
                    text:ndiPopup.tracking ? "Pause tracking" : "Enable for this notebook"; enabled:ndiPopup.ready
                    onClicked: {
                        if (!root.document) return;
                        ndiPopup.ready=false;
                        const notebook=String(root.document.id);
                        const enabling=!ndiPopup.tracking;
                        Values.ndiRequest("toggle", {notebook:notebook,current:Values.ndiIds(root.document),enabled:enabling,initializeFromModified:enabling && ndiPopup.initializeOlder}, function(result) {
                            if (!root.document || String(root.document.id)!==notebook) return;
                            if (result) { ndiPopup.initializeOlder=false; ndiPopup.showSettings=false; root.ndiRefresh(); }
                            else ndiPopup.ready=true;
                        });
                    }
                }
                Text { width:parent.width; visible:Values.ndiError!==""; text:Values.ndiError; font.pixelSize:20; color:"black"; wrapMode:Text.WordWrap }
                Rectangle { width:parent.width; height:1; color:"#cccccc" }
                Text { text:"THIS TABLET"; font.pixelSize:18; font.letterSpacing:2; color:"#555555" }
                Text { text:"Timezone"; font.pixelSize:27; font.bold:true; color:"black" }
                NdiControls.ComboBox {
                    id:timezonePicker; width:parent.width; height:64; font.pixelSize:24; leftPadding:18; rightPadding:50
                    model:ndiPopup.timezoneOptions; currentIndex:ndiPopup.timezoneOptions.indexOf(ndiPopup.timezone); enabled:ndiPopup.ready
                    background:Rectangle { color:"white"; border.color:"#777777"; border.width:1; radius:8 }
                    contentItem:Text { text:timezonePicker.displayText; font:timezonePicker.font; color:"black"; verticalAlignment:Text.AlignVCenter; elide:Text.ElideRight }
                    indicator:Text { text:"⌄"; font.pixelSize:28; color:"black"; x:parent.width-width-18; anchors.verticalCenter:parent.verticalCenter }
                    delegate:NdiControls.ItemDelegate {
                        required property string modelData
                        required property int index
                        width:timezonePicker.width; height:64
                        contentItem:Text { text:modelData; font.pixelSize:24; color:"black"; verticalAlignment:Text.AlignVCenter }
                        background:Rectangle { color:parent.highlighted ? "#dedede" : "white" }
                        highlighted:timezonePicker.highlightedIndex===index
                    }
                    popup.background:Rectangle { color:"white"; border.color:"black"; border.width:1 }
                    onActivated: { ndiPopup.ready=false; Values.ndiRequest("settings", {timezone:currentText}, function(result) { root.ndiRefresh(); }); }
                }
                Text { width:parent.width; text:"Applies to Modified view, new creation dates and new estimates. Previously saved creation dates do not move. Your tablet’s system clock is unchanged."; font.pixelSize:20; color:"#555555"; wrapMode:Text.WordWrap }
                Rectangle { width:parent.width; height:1; color:"#cccccc" }
                Text { text:"Date-history sync"; font.pixelSize:27; font.bold:true; color:"black" }
                Text { width:parent.width; text:ndiPopup.syncStatus; font.pixelSize:22; color:"#555555"; wrapMode:Text.WordWrap }
                Text { width:parent.width; text:"Your sync server is configured privately on this tablet. Notebook content and normal reMarkable sync are never changed."; font.pixelSize:20; color:"#555555"; wrapMode:Text.WordWrap }
                Item { width:1; height:12 }
            }
        }
    }
}
