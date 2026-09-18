import fs from 'node:fs';
const fw = '3.28.0.169';
const source = fs.readFileSync;
const inc = name => source(`qml/${name}.qml.inc`, 'utf8');
const affect = (path, root, body) => `AFFECT /${path}\n TRAVERSE ${root}\n LOCATE BEFORE ALL\n${body}\n END TRAVERSE\nEND AFFECT\n`;
const rebuild = (name, from, to) => ` REBUILD ${name}\n LOCATE BEFORE ALL\n REPLACE { ${from} } WITH { ${to} }\n END REBUILD\n`;
let q = `VERSION ${fw}\n`;
q += affect('qml/common/Values.qml','Item',`INSERT { ${inc('values')} }`);
q += affect('qml/device/view/documentview/DocumentView.qml','FocusScope#root',
    `INSERT {
       function ndiCloseFoldout() { toolbar.closeFoldout(); }
       Loader {
         id: ndiLoader
         anchors.fill: parent
         Component.onCompleted: setSource("file:///home/root/.local/lib/notebook-date-index/DatesPanel.qml", {documentView: root})
         onLoaded: item.ndiRefresh()
       }
    }\n` +
    rebuild('addPage', 'DocumentController.addPageWithTemplateAndPageSize(document.id,', 'Values.ndiAddPage(document,') +
    rebuild('onDocumentChanged', 'root.updatePageTags();', 'root.updatePageTags(); Qt.callLater(function() { if (ndiLoader.item) ndiLoader.item.ndiRefresh(); });'));
q += affect('qml/device/view/documentview/PagesActions.qml','Item#pageActions',
    `INSERT { property var ndiDuplicateTicket: null }\n` +
    rebuild('addPageToDocument','DocumentController.addPageWithTemplateAndPageSize(document.id,','Values.ndiAddPage(document,') +
    rebuild('duplicatePagesAction','DocumentController.copyPages(document.id, pages, document.id, insertIndex);',
    'ndiDuplicateTicket = Values.ndiBegin(document, pages.length, "duplicate"); DocumentController.copyPages(document.id, pages, document.id, insertIndex);') +
    `TRAVERSE Connections[.target=document]\n` + rebuild('onPagesAdded', 'if (!pageSelection.isEmpty)', 'if (Values.ndiFinish(document, pageActions.ndiDuplicateTicket, pageIndexes)) pageActions.ndiDuplicateTicket = null; if (!pageSelection.isEmpty)') + `END TRAVERSE`);
q += affect('qml/device/view/documentview/HwcDialog.qml','Item#root',
    rebuild('createConvertedDocument','DocumentController.addPageWithTemplateAndPageSize(document.id,','Values.ndiAddPage(document,'));
// Quick Sheets uses the same successful-creation callback as other notebook pages.
const library = source('../remarkable-beta-os/.cache/firmware/'+fw+'/resources/qt/qml/xofm/modules/library/ui/qml/LibraryActions.qml','utf8');
const before = library.slice(0,library.indexOf('DocumentController.addPageWithTemplateAndPageSize'));
const func = [...before.matchAll(/function (\w+)\(/g)].at(-1)[1];
q += affect('qt/qml/xofm/modules/library/ui/qml/LibraryActions.qml','Action#root',
    rebuild(func,'DocumentController.addPageWithTemplateAndPageSize(document.id,','Values.ndiAddPage(document,'));
q += `AFFECT /qt/qml/xofm/libs/toolbar/qml/AdditionalEditingToolsMenu.qml\n IMPORT common 1.0\n TRAVERSE ToolbarTool#root\n TRAVERSE ColumnLayout\n LOCATE BEFORE ALL\n INSERT {
 ToolbarTool {
   toolbar: root.toolbar
   type: ToolbarTool.Type.FoldoutButton
   label: "Dates"
   visible: root.toolbar.documentType === "note"
   shouldShow: root.toolbar.documentType === "note"
   iconSource: "qrc:/ark/icons/calendar"
   onPressed: Values.ndiOpenRequested()
 }
 }\n END TRAVERSE\n END TRAVERSE\nEND AFFECT\n`;
fs.mkdirSync('build',{recursive:true});
const popup = inc('popup').replaceAll('root.', 'documentView.')
    .replaceAll('documentView.ndiRefresh()', 'ndiHost.ndiRefresh()')
    .replaceAll('toolbar.closeFoldout()', 'documentView.ndiCloseFoldout()');
const panel = `import QtQuick\nimport QtQuick.Controls 2.15 as NdiControls\nimport com.remarkable\nimport common 1.0\nItem { id: ndiHost; required property var documentView;\n${popup}\n}\n`;
fs.writeFileSync('build/DatesPanel.qml',panel);
fs.writeFileSync('build/DatesPanel-preview.qml',panel.replace('enabled: ndiPopup.ready','enabled: false').replace('Enable for this notebook','Preview — tracking disabled'));
fs.writeFileSync('build/notebook-date-index.source.qmd',q);
const preview = q.replace('enabled: ndiPopup.ready', 'enabled: false')
    .replace('Enable for this notebook', 'Preview — tracking disabled')
    .replace('function ndiBegin(doc, count, source) {', 'function ndiBegin(doc, count, source) { return null;')
    .replaceAll('WITH { Values.ndiAddPage(document, }', 'WITH { DocumentController.addPageWithTemplateAndPageSize(document.id, }');
fs.writeFileSync('build/notebook-date-index-preview.source.qmd',preview);
