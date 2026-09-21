import fs from 'node:fs';
const contract = JSON.parse(fs.readFileSync('target.json','utf8'));
const fw = contract.firmware;
const target = process.env.NDI_TARGET || contract.device;
if (target !== 'pro' || fw !== '3.29.0.148')
    throw new Error('This branch is qualified only for Pro 3.29.0.148');
const resources = process.env.NDI_RESOURCES ||
    '/Users/mdf/code/remarkable-beta-os/.cache/firmware/'+fw+'/resources';
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
    rebuild('addPage', 'DocumentController.addPageWithTemplateAndPageSize(document.id,', 'Values.ndiAddPage(DocumentController, document,') +
    rebuild('onDocumentChanged', 'root.updatePageTags();', 'root.updatePageTags(); Qt.callLater(function() { if (ndiLoader.item) ndiLoader.item.ndiRefresh(); });'));
q += affect('qml/device/view/documentview/PagesActions.qml','Item#pageActions',
    `INSERT { property var ndiDuplicateTicket: null }\n` +
    rebuild('addPageToDocument','DocumentController.addPageWithTemplateAndPageSize(document.id,','Values.ndiAddPage(DocumentController, document,') +
    rebuild('duplicatePagesAction','DocumentController.copyPages(document.id, pages, document.id, insertIndex);',
    'ndiDuplicateTicket = Values.ndiBegin(document, pages.length, "duplicate"); DocumentController.copyPages(document.id, pages, document.id, insertIndex);') +
    `TRAVERSE Connections[.target=document]\n` + rebuild('onPagesAdded', 'if (!pageSelection.isEmpty)', 'if (Values.ndiFinish(document, pageActions.ndiDuplicateTicket, pageIndexes)) pageActions.ndiDuplicateTicket = null; if (!pageSelection.isEmpty)') + `END TRAVERSE`);
q += affect('qml/device/view/documentview/HwcDialog.qml','Item#root',
    rebuild('createConvertedDocument','DocumentController.addPageWithTemplateAndPageSize(document.id,','Values.ndiAddPage(DocumentController, document,'));
// Quick Sheets uses the same successful-creation callback as other notebook pages.
const library = source(resources+'/qt/qml/xofm/modules/library/ui/qml/LibraryActions.qml','utf8');
const before = library.slice(0,library.indexOf('DocumentController.addPageWithTemplateAndPageSize'));
const func = [...before.matchAll(/function (\w+)\(/g)].at(-1)[1];
q += affect('qt/qml/xofm/modules/library/ui/qml/LibraryActions.qml','Action#root',
    rebuild(func,'DocumentController.addPageWithTemplateAndPageSize(document.id,','Values.ndiAddPage(DocumentController, document,'));
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
// Pro gets a direct calendar icon immediately above BetterTOC. The existing
// extension-button accounting reserves space without hiding native tools.
// Move retains the compact notebook menu; Pro uses it only as a short-toolbar fallback.
if (target === 'pro') q += `AFFECT /qt/qml/xofm/libs/toolbar/qml/Toolbar.qml
 IMPORT common 1.0
 TRAVERSE FocusScope#root > Item#toolbar > GridLayout#toolLayout
 LOCATE BEFORE ToolbarTool#tocButton
 INSERT {
   ToolbarTool {
     id: ndiDatesButton
     toolbar: root
     type: ToolbarTool.Type.ToolbarButton
     property bool _isExtensionButton: true
     label: "Dates"
     iconSource: "qrc:/ark/icons/calendar"
     visible: root.documentType === "note" && root.expanded && root.stockShowableToolsCount > 7
     shouldShow: root.documentType === "note" && root.stockShowableToolsCount > 7
     onPressed: { root.closeFoldout(); Values.ndiOpenRequested(); }
   }
 }
 END TRAVERSE
END AFFECT
`;
q += `AFFECT /qt/qml/xofm/libs/toolbar/qml/SettingsMenu.qml
 IMPORT common 1.0
 TRAVERSE ToolbarTool#root
 TRAVERSE Component#settingsComponent > ColumnLayout#content
 LOCATE BEFORE ALL
 INSERT {
   ToolbarTool {
     toolbar: root.toolbar
     type: ToolbarTool.Type.FoldoutButton
     Layout.fillWidth: true
     label: "Dates"
     visible: root.documentType === "note" && root.toolbar.stockShowableToolsCount <= 7
     shouldShow: root.documentType === "note" && root.toolbar.stockShowableToolsCount <= 7
     iconSource: "qrc:/ark/icons/calendar"
     onPressed: Values.ndiOpenRequested()
   }
 }
 END TRAVERSE
 END TRAVERSE
END AFFECT
`;
fs.mkdirSync('build',{recursive:true});
const popup = inc('popup').replaceAll('root.', 'documentView.')
    .replaceAll('documentView.ndiRefresh()', 'ndiHost.ndiRefresh()')
    .replaceAll('toolbar.closeFoldout()', 'documentView.ndiCloseFoldout()');
const panel = `import QtQuick\nimport QtQuick.Controls 2.15 as NdiControls\nimport "DateTree.js" as DateTree\nimport com.remarkable\nimport common 1.0\nItem { id: ndiHost; required property var documentView;\n${popup}\n}\n`;
fs.copyFileSync('qml/date-tree.js','build/DateTree.js');
fs.writeFileSync('build/DatesPanel.qml',panel);
fs.writeFileSync('build/DatesPanel-preview.qml',panel.replace('enabled: ndiPopup.ready','enabled: false').replace('Enable for this notebook','Preview — tracking disabled'));
fs.writeFileSync('build/notebook-date-index.source.qmd',q);
const preview = q.replace('enabled: ndiPopup.ready', 'enabled: false')
    .replace('Enable for this notebook', 'Preview — tracking disabled')
    .replace('function ndiBegin(doc, count, source) {', 'function ndiBegin(doc, count, source) { return null;')
    .replaceAll('WITH { Values.ndiAddPage(DocumentController, document, }', 'WITH { DocumentController.addPageWithTemplateAndPageSize(document.id, }');
fs.writeFileSync('build/notebook-date-index-preview.source.qmd',preview);
