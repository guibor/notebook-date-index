// Real QML lexical boundary: the observer imports no native controller.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const code=fs.readFileSync('qml/values.qml.inc','utf8').replaceAll('Document.Notebook','1');
fs.writeFileSync('build/CreationObserver.qml',`import QtQuick\nItem { ${code} }\n`);
fs.writeFileSync('build/creation-runtime.qml',`import QtQuick
Item {
 id: caller
 property var pages: ["a"]
 property int callbacks: 0
 property int records: 0
 QtObject {
   id: nativeController
   function addPageWithTemplateAndPageSize(id,index,template,size,done) {
     caller.pages.push("b"); done("stock-success"); return 7;
   }
 }
 CreationObserver {
   id: observer
   function ndiRequest(action,body,done) {
     if (caller.callbacks !== 1 || action !== "record" || body.created[0] !== "b") throw Error("invalid recording");
     caller.records++;
   }
 }
 Component.onCompleted: {
   let doc = {id:"book",fileType:1,get pageCount(){return caller.pages.length},idForPage:function(i){return caller.pages[i]}};
   let result=observer.ndiAddPage(nativeController,doc,1,"Blank",{},function(value){ if(value !== "stock-success") throw Error("lost callback argument"); caller.callbacks++; });
   if(result !== 7 || caller.callbacks !== 1 || caller.records !== 1) { console.error("Creation runtime FAILED"); Qt.exit(1); }
   else { console.log("Creation runtime PASSED"); Qt.quit(); }
 }
}
`);
const files=['qml/device/view/documentview/DocumentView.qml','qml/device/view/documentview/PagesActions.qml','qml/device/view/documentview/HwcDialog.qml','qt/qml/xofm/modules/library/ui/qml/LibraryActions.qml'];
for(const f of files) {
 const generated=fs.readFileSync(`build/notebook-date-index-composed/${f}`,'utf8');
 assert.match(generated,/Values\.ndiAddPage\(DocumentController,\s*document,/);
 assert.doesNotMatch(generated,/Values\.ndiAddPage\(document,/);
 const preview=fs.readFileSync(`build/notebook-date-index-preview-composed/${f}`,'utf8');
 assert.doesNotMatch(preview,/Values\.ndiAddPage\(/);
}
