import fs from 'node:fs';
let popup=fs.readFileSync('qml/popup.qml.inc','utf8').replaceAll('Values.','bridge.').replaceAll('target: Values','target: bridge').replaceAll('Document.Notebook','1');
let harness=`import QtQuick
import QtQuick.Controls 2.15 as NdiControls
Rectangle {
 id: root
 width: 1000; height: 1400
 color: "white"
 property var document: ({id: "00000000-0000-0000-0000-000000000001", fileType: 1, pageForId: function(id) {return 1;}})
 function openPage(page) {}
 QtObject { id: toolbar; function closeFoldout() {} }
 QtObject {
   id: bridge
   property string ndiError: ""
   signal ndiOpenRequested()
   signal ndiChanged(string notebook)
   function ndiIds(doc) { return []; }
   function ndiRequest(action, body, done) {
     if (done) done({enabled: true, groups: [{day:"2026-09-18",pages:[{id:"one",number:2},{id:"two",number:5}]}]});
   }
 }
 ${popup}
 Timer { interval: 100; running: true; onTriggered: { ndiPopup.open(); ndiPopup.expandedDay="2026-09-18"; } }
 Timer { interval: 600; running: true; onTriggered: {
   if (!ndiPopup.opened || ndiPopup.groups.length !== 1 || !ndiPopup.ready) { console.error("Dates UI runtime FAILED"); Qt.exit(1); }
   else {
     if (trackingButton.height < 64 || closeDatesButton.height < 64 || timezonePicker.height < 64) { console.error("Touch targets too small"); Qt.exit(1); return; }
     ndiPopup.background.parent.grabToImage(function(image) { image.saveToFile("build/dates-panel.png"); console.log("Dates UI runtime PASSED"); Qt.quit(); });
   }
 } }
}
`;
fs.writeFileSync('build/ui-harness.qml',harness);
