import fs from 'node:fs';
const resources=process.env.NDI_RESOURCES || '/Users/mdf/code/remarkable-beta-os/.cache/firmware/3.29.0.148/resources';
let popup=fs.readFileSync('qml/popup.qml.inc','utf8').replaceAll('Values.','bridge.').replaceAll('target: Values','target: bridge').replaceAll('Document.Notebook','1').replace('qrc:/ark/icons/cog','file://'+resources+'/ark/icons/cog');
fs.copyFileSync('qml/date-tree.js','build/DateTree.js');
let harness=`import QtQuick
import QtQuick.Controls 2.15 as NdiControls
import "DateTree.js" as DateTree
Rectangle {
 id: root
 width: ${process.env.NDI_UI_WIDTH || 1000}; height: ${process.env.NDI_UI_HEIGHT || 1400}
 color: "white"
 property var document: ({id: "00000000-0000-0000-0000-000000000001", fileType: 1, pageForId: function(id) {return ({one:1,two:4,three:8,four:11})[id] ?? -1;}})
 property int openedPage: -1
 function openPage(page) { openedPage=page; }
 QtObject { id: toolbar; function closeFoldout() {} }
 QtObject {
   id: bridge
   property string ndiError: ""
   property bool enabled: true
   property bool baseline: false
   property string zone: "Asia/Jerusalem"
   signal ndiOpenRequested()
   signal ndiChanged(string notebook)
   function ndiIds(doc) { return []; }
   function ndiRequest(action, body, done) {
     if(action==="toggle") { enabled=body.enabled; baseline=body.initializeFromModified; }
     if(action==="settings") zone=body.timezone;
     const day=body.mode==="modified" ? "2026-09-19" : "2026-09-18";
     const estimated=body.mode!=="modified";
     const pages=[{id:"one",number:2},{id:"two",number:5,estimated:estimated}];
     if (body.mode==="modified") pages.reverse();
     if (done) done({enabled:enabled, timezone:zone, mode:body.mode||"created", undated:1, estimated:estimated ? 1 : 0, groups:[{day:day,pages:pages},{day:"2026-08-31",pages:[{id:"three",number:9}]},{day:"2025-12-01",pages:[{id:"four",number:12}]}]});
   }
 }
 ${popup}
 Timer { interval: 100; running: true; onTriggered: { ndiPopup.open(); ndiPopup.expanded=({"d:2026-09-18":true}); } }
 Timer { interval: 600; running: true; onTriggered: {
   if (!ndiPopup.opened || ndiPopup.groups.length !== 3 || !ndiPopup.ready || settingsView.visible) { console.error("Dates UI runtime FAILED"); Qt.exit(1); }
   else {
     if (createdTab.height < 64 || trackingButton.height < 64 || closeDatesButton.height < 64 || timezonePicker.height < 64) { console.error("Touch targets too small"); Qt.exit(1); return; }
     ndiPopup.background.parent.grabToImage(function(image) { image.saveToFile("build/dates-panel.png"); });
   }
 } }
 Timer { interval:800; running:true; onTriggered: {
   modifiedTab.clicked();
   if (ndiPopup.mode!=="modified" || ndiPopup.groups[0].day!=="2026-09-19") { console.error("Mode switch failed"); Qt.exit(1); }
   settingsButton.clicked(); trackingButton.clicked(); settingsButton.clicked();
   if (ndiPopup.tracking || !initializeCheck.visible || ndiPopup.initializeOlder) { console.error("Tracking settings failed"); Qt.exit(1); }
   ndiPopup.initializeOlder=true;
 } }
 Timer { interval:1000; running:true; onTriggered: {
   if(closeDatesButton.x+closeDatesButton.width > header.width+1 || dateList.height<100) { console.error("Panel geometry failed"); Qt.exit(1); }
   ndiPopup.background.parent.grabToImage(function(image) { image.saveToFile("build/dates-settings.png"); });
 } }
 Timer { interval:1200; running:true; onTriggered: {
   trackingButton.clicked();
   if (!ndiPopup.tracking || !bridge.baseline || ndiPopup.showSettings || ndiPopup.initializeOlder) { console.error("Explicit backfill toggle failed"); Qt.exit(1); }
   calendarViewButton.clicked();
   if (!calendarMonthView.visible || dateList.visible || ndiPopup.mode!=="modified" || !calendarViewButton.primary || listViewButton.primary) { console.error("Independent calendar choice failed"); Qt.exit(1); }
 } }
 Timer { interval:1500; running:true; onTriggered: {
   const month=ndiPopup.monthData;
   if (month.title!=="September 2026" || month.pages!==2 || monthCard.width/7<64 || monthGrid.y+monthGrid.height>calendarMonthView.height) { console.error("Calendar month or geometry failed"); Qt.exit(1); }
   ndiPopup.background.parent.grabToImage(function(image) { image.saveToFile("build/dates-calendar.png"); });
 } }
 Timer { interval:1700; running:true; onTriggered: {
   const spillover=ndiPopup.monthData.cells.find(function(cell) {return cell.day==="2026-08-31";});
   if (!spillover || spillover.inMonth || spillover.count!==1) { console.error("Calendar spillover cell failed"); Qt.exit(1); }
   ndiPopup.selectDay(spillover.day);
   if (!calendarDay.visible || ndiPopup.selectedPages[0].id!=="three") { console.error("Calendar spillover selection failed"); Qt.exit(1); }
   calendarBack.clicked();
   if (!calendarMonthView.visible || ndiPopup.monthData.title!=="September 2026") { console.error("Calendar position lost"); Qt.exit(1); }
   previousMonth.clicked();
   if (ndiPopup.monthData.title!=="August 2026") { console.error("Previous month arrow failed"); Qt.exit(1); }
   nextMonth.clicked();
   if (ndiPopup.monthData.title!=="September 2026" || nextMonth.enabled) { console.error("Next month arrow or boundary failed"); Qt.exit(1); }
   ndiPopup.selectDay("2026-09-19");
   if (ndiPopup.selectedPages[0].number!==2 || ndiPopup.selectedPages[1].number!==5 || ndiPopup.groups[0].pages[0].number!==5) { console.error("Modified calendar page order failed"); Qt.exit(1); }
 } }
 Timer { interval:1900; running:true; onTriggered: {
   ndiPopup.background.parent.grabToImage(function(image) { image.saveToFile("build/dates-calendar-day.png"); });
 } }
 Timer { interval:2100; running:true; onTriggered: {
   createdTab.clicked();
   if (ndiPopup.presentation!=="calendar" || ndiPopup.selectedDay || ndiPopup.byDay["2026-09-19"] || !ndiPopup.byDay["2026-09-18"]) { console.error("Calendar date-basis change failed"); Qt.exit(1); }
   ndiPopup.selectDay("2026-09-18");
 } }
 Timer { interval:2300; running:true; onTriggered: {
   dayPages.itemAtIndex(1).clicked();
   if (root.openedPage!==4) { console.error("Stable page navigation failed"); Qt.exit(1); }
   console.log("Dates UI runtime PASSED"); Qt.quit();
 } }
}
`;
fs.writeFileSync('build/ui-harness.qml',harness);
