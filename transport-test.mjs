// Exercise the actual QML request queue against the actual Go HTTP service.
// All data is synthetic; never use device credentials or notebook files.
import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
const data=fs.mkdtempSync(path.resolve('build/transport-test-'));
const server=spawn(path.resolve('build/notebook-date-index-host'),['--preview','--data',data],{stdio:['ignore','pipe','pipe']});
let serverOutput='';
server.stdout.on('data',b=>serverOutput+=b);
server.stderr.on('data',b=>serverOutput+=b);
try {
  for(let n=0;n<100 && !fs.existsSync(path.join(data,'token'));n++) await delay(30);
  if(!fs.existsSync(path.join(data,'token'))) throw Error('Test server failed: '+serverOutput);
  let values=fs.readFileSync('qml/values.qml.inc','utf8')
    .replace('file:///home/root/.local/share/notebook-date-index/token','file://'+path.join(data,'token'))
    .replaceAll('Document.Notebook','1');
  // This diagnostic logs only status and response, never token or request IDs.
  values=values.replace('let result = null;', 'console.log("transport status=" + req.status + " response=" + req.responseText); let result = null;');
  const harness=`import QtQuick
Item {
 ${values}
 Component.onCompleted: ndiRequest("query", {notebook:"00000000-0000-0000-0000-000000000001",current:["00000000-0000-0000-0000-000000000002"]}, function(result) {
   if (!result || result.timezone !== "Asia/Jerusalem" || result.enabled !== false || result.groups.length !== 0) { console.error("Dates transport FAILED: " + ndiError); Qt.exit(1); }
   else { console.log("Dates transport PASSED"); Qt.quit(); }
 })
 Timer { interval: 8000; running: true; onTriggered: { console.error("Dates transport timed out"); Qt.exit(2); } }
}`;
  const file=path.join(data,'request.qml');fs.writeFileSync(file,harness);
  const qml=spawn('qml',['--disable-context-sharing',file],{env:{...process.env,QT_QUICK_CONTROLS_STYLE:'Basic',QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software',QML_XHR_ALLOW_FILE_READ:'1'},stdio:['ignore','pipe','pipe']});
  let output='';qml.stdout.on('data',b=>output+=b);qml.stderr.on('data',b=>output+=b);
  const code=await new Promise((resolve,reject)=>{qml.on('exit',resolve);qml.on('error',reject)});
  process.stdout.write(output);
  if(code!==0 || !output.includes('Dates transport PASSED')) process.exitCode=1;
} finally {
  server.kill('SIGTERM');
  await new Promise(resolve=>{if(server.exitCode!==null)resolve();else server.on('exit',resolve)});
  fs.rmSync(data,{recursive:true,force:true});
}
