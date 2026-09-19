component DatesButton: NdiControls.Button {
    id: button
    property bool primary: false
    property bool quiet: false
    property color iconInk: primary && !down ? "white" : "black"
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
    ndiPopup.prepareScope(notebook, mode);
    const generation = ++ndiPopup.requestGeneration;
    Values.ndiRequest("query", {notebook:notebook, current:Values.ndiIds(root.document), mode:mode}, function(result) {
        if (!root.document || String(root.document.id) !== notebook || generation !== ndiPopup.requestGeneration || mode !== ndiPopup.mode) return;
        if (result) {
            ndiPopup.tracking = result.enabled;
            // Preserve delegate identity when a background refresh is unchanged.
            if (JSON.stringify(ndiPopup.groups) !== JSON.stringify(result.groups)) ndiPopup.groups = result.groups;
            ndiPopup.timezone = result.timezone || "Asia/Jerusalem";
            ndiPopup.undated = result.undated || 0; ndiPopup.estimates = result.estimated || 0;
            ndiPopup.warning = result.warning || "";
            ndiPopup.syncStatus = result.sync || "Local only · sync not configured";
            ndiPopup.focusedMonth = ndiPopup.focusedMonth < 0 ? ndiPopup.calendarInfo.latest : DateTree.shiftMonth(ndiPopup.focusedMonth, 0, ndiPopup.calendarInfo);
            ndiPopup.refreshError = "";
            ndiPopup.ready = true;
        } else {
            ndiPopup.refreshError = Values.ndiError || "Could not refresh dates. Close and reopen to retry.";
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
    property bool settingsBusy: false
    property string scopeKey: ""
    property string refreshError: ""
    property var groups: []
    property var expanded: ({})
    property var dateRows: DateTree.rows(groups, expanded)
    property string mode: "created"
    property string presentation: "list"
    property string selectedDay: ""
    property var byDay: DateTree.dayGroups(groups)
    property var calendarInfo: DateTree.calendarRange(groups)
    property int focusedMonth: -1
    property var monthData: DateTree.calendarMonth(focusedMonth < 0 ? calendarInfo.latest : focusedMonth, byDay)
    property var selectedPages: DateTree.pagesForDay(byDay, selectedDay, mode)
    property int requestGeneration: 0
    property int undated: 0
    property int estimates: 0
    property string warning: ""
    property string syncStatus: ""
    property string timezone: "Asia/Jerusalem"
    property var timezoneOptions: ["Asia/Jerusalem", "UTC", "Europe/London", "Europe/Paris", "America/New_York", "America/Los_Angeles", "Asia/Tokyo"].indexOf(timezone) >= 0
        ? ["Asia/Jerusalem", "UTC", "Europe/London", "Europe/Paris", "America/New_York", "America/Los_Angeles", "Asia/Tokyo"]
        : [timezone, "Asia/Jerusalem", "UTC", "Europe/London", "Europe/Paris", "America/New_York", "America/Los_Angeles", "Asia/Tokyo"]
    function prepareScope(notebook, nextMode) {
        const key = notebook + "|" + nextMode;
        if (scopeKey === key) return;
        ready = false; groups = []; expanded = ({}); selectedDay = ""; focusedMonth = -1;
        tracking = false; undated = 0; estimates = 0; syncStatus = ""; settingsBusy = false;
        warning = ""; refreshError = ""; scopeKey = key;
    }
    function switchMode(next) {
        if (mode === next) return;
        mode = next;
        root.ndiRefresh();
    }
    function switchPresentation(next) {
        presentation = next; selectedDay = "";
    }
    function selectDay(day) {
        if (byDay[day] && byDay[day].pages.length) selectedDay = day;
    }
    function moveMonth(delta) {
        focusedMonth = DateTree.shiftMonth(focusedMonth, delta, calendarInfo);
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
    dim: false
    enter: Transition {}
    exit: Transition {}
    width: Math.min(root.width - 64, 900); height: Math.min(root.height - 100, 1200)
    x: (root.width - width) / 2; y: (root.height - height) / 2
    padding: 32
    onAboutToShow: {
        selectedDay = ""; showSettings = false; initializeOlder = false;
        root.ndiRefresh();
    }
    background: Rectangle { color:"white"; border.color:"black"; border.width:2; radius:14 }
    contentItem: Item {
        Item {
            id: header
            width: parent.width; height: 64
            DatesButton { id: backButton; visible:ndiPopup.showSettings; width:64; text:"‹"; font.pixelSize:40; quiet:true; onClicked:ndiPopup.showSettings=false }
            Text {
                x: ndiPopup.showSettings ? 72 : 0
                width: parent.width - x - (ndiPopup.showSettings ? 72 : 296)
                height:64; text:ndiPopup.showSettings ? "Dates settings" : "Dates"
                font.pixelSize:36; font.bold:true; color:"black"; verticalAlignment:Text.AlignVCenter; elide:Text.ElideRight
            }
            Rectangle {
                id: layoutPicker; x:parent.width-286; width:140; height:64; radius:8; color:"#eeeeee"; visible:!ndiPopup.showSettings
                Row {
                    anchors.fill:parent; spacing:4
                    DatesButton {
                        id:listViewButton; width:68; height:64; quiet:true; primary:ndiPopup.presentation==="list"
                        onClicked:ndiPopup.switchPresentation("list")
                        contentItem:Item {
                            Column {
                                anchors.centerIn:parent; spacing:6
                                Repeater {
                                    model:3
                                    Row { spacing:5; Rectangle { width:4; height:4; color:listViewButton.iconInk } Rectangle { width:22; height:4; color:listViewButton.iconInk } }
                                }
                            }
                        }
                    }
                    DatesButton {
                        id:calendarViewButton; width:68; height:64; quiet:true; primary:ndiPopup.presentation==="calendar"
                        onClicked:ndiPopup.switchPresentation("calendar")
                        contentItem:Item {
                            Rectangle {
                                anchors.centerIn:parent; width:30; height:28; radius:3; color:"transparent"; border.width:2; border.color:calendarViewButton.iconInk
                                Rectangle { x:1; y:7; width:28; height:2; color:parent.border.color }
                                Repeater { model:2; Rectangle { required property int index; x:7+index*14; y:-4; width:2; height:8; color:parent.border.color } }
                                Grid { x:7; y:14; columns:3; spacing:4; Repeater { model:6; Rectangle { width:3; height:3; color:calendarViewButton.iconInk } } }
                            }
                        }
                    }
                }
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
            ListView {
                id: dateList
                visible:ndiPopup.presentation==="list" && ndiPopup.ready
                anchors { top:viewCaption.bottom; topMargin:18; left:parent.left; right:parent.right; bottom:dateFooter.top; bottomMargin:14 }
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
            }
                Column {
                    id:emptyState
                    anchors.centerIn:dateList; width:dateList.width-36; spacing:18
                    visible:!ndiPopup.ready || (ndiPopup.presentation==="list" && ndiPopup.groups.length===0)
                    Text {
                        width:parent.width; horizontalAlignment:Text.AlignHCenter; wrapMode:Text.WordWrap
                        text:!ndiPopup.ready ? (ndiPopup.refreshError ? "Dates unavailable" : "Loading dates…") : (ndiPopup.mode==="modified" ? "No saved modification dates" : "Your page history starts here")
                        font.pixelSize:28; font.bold:true; color:"black"
                    }
                    Text {
                        width:parent.width; horizontalAlignment:Text.AlignHCenter; wrapMode:Text.WordWrap
                        text:ndiPopup.refreshError || ndiPopup.warning || (!ndiPopup.ready ? "" : (ndiPopup.mode==="modified" ? "Dates appear here when the notebook saves a page’s last edit." : (ndiPopup.tracking ? "Add a page and its creation date will appear here." : "Turn on tracking in settings to remember new pages. You can also include older pages using estimated dates.")))
                        font.pixelSize:22; color:"#555555"
                    }
                    DatesButton {
                        anchors.horizontalCenter:parent.horizontalCenter; width:Math.min(parent.width,360)
                        visible:ndiPopup.ready && ndiPopup.mode==="created" && !ndiPopup.tracking
                        text:"Set up tracking"; primary:true; onClicked:ndiPopup.showSettings=true
                    }
                }
            Item {
                id:calendarMonthView
                visible:ndiPopup.ready && ndiPopup.presentation==="calendar" && ndiPopup.selectedDay===""
                anchors { top:viewCaption.bottom; topMargin:18; left:parent.left; right:parent.right; bottom:dateFooter.top; bottomMargin:14 }
                clip:true
                Item {
                    id:monthCard
                    width:parent.width; height:Math.min(parent.height,566)
                    DatesButton { id:previousMonth; width:64; height:64; quiet:true; text:"‹"; font.pixelSize:40; enabled:ndiPopup.focusedMonth>ndiPopup.calendarInfo.oldest; onClicked:ndiPopup.moveMonth(-1) }
                    DatesButton { id:nextMonth; anchors.right:parent.right; width:64; height:64; quiet:true; text:"›"; font.pixelSize:40; enabled:ndiPopup.focusedMonth<ndiPopup.calendarInfo.latest; onClicked:ndiPopup.moveMonth(1) }
                    Text { id:monthHeading; x:72; width:parent.width-144; height:52; text:ndiPopup.monthData.title; font.pixelSize:29; font.bold:true; color:"black"; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter }
                    Text { anchors { top:monthHeading.bottom; horizontalCenter:parent.horizontalCenter } text:ndiPopup.monthData.pages ? DateTree.pageCount(ndiPopup.monthData.pages) : "No dated pages"; font.pixelSize:20; color:"#555555" }
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
                            model:ndiPopup.monthData.cells
                            Item {
                                required property var modelData
                                width:monthGrid.width/7; height:Math.max(54,Math.min(72,(monthCard.height-124)/6))
                                Rectangle { anchors { fill:parent; margins:3 } radius:8; color:dayTap.pressed ? "#dedede" : "white" }
                                Text { anchors { top:parent.top; topMargin:7; horizontalCenter:parent.horizontalCenter } text:modelData.number || ""; font.pixelSize:25; font.bold:modelData.count>0; color:modelData.inMonth ? (modelData.count ? "black" : "#555555") : "#888888" }
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
                anchors { top:viewCaption.bottom; topMargin:18; left:parent.left; right:parent.right; bottom:dateFooter.top; bottomMargin:14 }
                DatesButton { id:calendarBack; width:parent.width; height:64; text:"‹  "+ndiPopup.monthData.title; quiet:true; onClicked:ndiPopup.selectedDay="" }
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
                text:(ndiPopup.refreshError && ndiPopup.ready ? "Showing saved dates. "+ndiPopup.refreshError+"\n" : "")+(ndiPopup.presentation==="calendar" ? (ndiPopup.selectedDay ? "Choose a page to open it." : "Use the arrows to change month. Tap a marked day.") : (ndiPopup.groups.length ? "Tap a day to open its first page. + shows all pages." : ""))+(ndiPopup.undated ? "\n"+ndiPopup.undated+(ndiPopup.undated===1 ? " page has" : " pages have")+" no "+(ndiPopup.mode==="created" ? "creation" : "modification")+" date." : "")+(ndiPopup.estimates ? "\nEstimated dates came from last modified, not observed creation." : "")
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
                    checked:ndiPopup.initializeOlder; enabled:ndiPopup.ready && !ndiPopup.settingsBusy
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
                    text:ndiPopup.tracking ? "Pause tracking" : "Enable for this notebook"; enabled:ndiPopup.ready && !ndiPopup.settingsBusy
                    onClicked: {
                        if (!root.document) return;
                        ndiPopup.settingsBusy=true;
                        const notebook=String(root.document.id);
                        const enabling=!ndiPopup.tracking;
                        Values.ndiRequest("toggle", {notebook:notebook,current:Values.ndiIds(root.document),enabled:enabling,initializeFromModified:enabling && ndiPopup.initializeOlder}, function(result) {
                            if (!root.document || String(root.document.id)!==notebook) return;
                            ndiPopup.settingsBusy=false;
                            if (result) { ndiPopup.tracking=result.enabled; ndiPopup.initializeOlder=false; ndiPopup.showSettings=false; root.ndiRefresh(); }
                        });
                    }
                }
                Text { width:parent.width; visible:Values.ndiError!==""; text:Values.ndiError; font.pixelSize:20; color:"black"; wrapMode:Text.WordWrap }
                Rectangle { width:parent.width; height:1; color:"#cccccc" }
                Text { text:"THIS TABLET"; font.pixelSize:18; font.letterSpacing:2; color:"#555555" }
                Text { text:"Timezone"; font.pixelSize:27; font.bold:true; color:"black" }
                NdiControls.ComboBox {
                    id:timezonePicker; width:parent.width; height:64; font.pixelSize:24; leftPadding:18; rightPadding:50
                    model:ndiPopup.timezoneOptions; currentIndex:ndiPopup.timezoneOptions.indexOf(ndiPopup.timezone); enabled:ndiPopup.ready && !ndiPopup.settingsBusy
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
                    onActivated: { ndiPopup.settingsBusy=true; Values.ndiRequest("settings", {timezone:currentText}, function(result) { ndiPopup.settingsBusy=false; if (result && result.timezone) ndiPopup.timezone=result.timezone; root.ndiRefresh(); }); }
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
