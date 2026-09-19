// Actual device-to-hub-to-device delivery check. No synthetic page creation.
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const [pro,move,notebook]=process.argv.slice(2);
assert.match(notebook||'',/^[0-9a-f-]{36}$/);
const opts=['-o','BatchMode=yes','-o','PasswordAuthentication=no','-o','KbdInteractiveAuthentication=no','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5','-i',process.env.HOME+'/.ssh/id_ed25519_remarkable_new'];
const remote=(host,cmd,input)=>execFileSync('ssh',[...opts,'root@'+host,cmd],{input,encoding:'utf8',timeout:15000,maxBuffer:16<<20});
for(const [host,fp,model] of [[pro,'SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE','Ferrari'],[move,'SHA256:osLWO+xA0s/qhzWV2jtGWAF6NlD/KEi/d6CEkt8MZMk','Chiappa']]) {
 assert.match(host||'',/^\d+\.\d+\.\d+\.\d+$/);
 const keys=execFileSync('ssh-keyscan',['-T','3','-t','ed25519',host],{stdio:['ignore','pipe','ignore']});
 assert.equal(execFileSync('ssh-keygen',['-lf','-'],{input:keys,encoding:'utf8'}).trim().split(/\s+/)[1],fp);
 assert.equal(remote(host,'cat /sys/devices/soc0/machine').trim(),'reMarkable '+model);
}
const data='/home/root/.local/share/notebook-date-index/',native='/home/root/.local/share/remarkable/xochitl/'+notebook+'.content';
const before={};
for(const host of [pro,move]) before[host]=remote(host,'cat '+native);
const ids=host=>JSON.parse(before[host]).cPages.pages.filter(p=>!p.deleted?.value).map(p=>p.id);
function query(host) {
 return JSON.parse(remote(host,'/home/root/.vellum/bin/curl -fsS --max-time 8 -H "Content-Type: application/json;charset=UTF-8" -H "X-Date-Index-Token: $(cat '+data+'token)" --data-binary @- http://127.0.0.1:18742/v1/query',JSON.stringify({notebook,current:ids(host),mode:'created'})));
}
const pv=query(pro); let mv=query(move);
const pi=JSON.parse(remote(pro,'cat '+data+notebook+'.json'));
const events=JSON.parse(remote(pro,'cat '+data+'sync-events/'+notebook+'.json')).events.filter(e=>e.device==='pro');
assert.ok(events.length>0);
for(let i=0;i<12;i++) {
 if(mv.sync==='Up to date' && mv.groups.reduce((n,g)=>n+g.pages.length,0)>=pi.pages.filter(p=>ids(move).includes(p.id)).length) break;
 await new Promise(r=>setTimeout(r,1000)); mv=query(move);
}
const mi=JSON.parse(remote(move,'cat '+data+notebook+'.json'));
const received=JSON.parse(remote(move,'cat '+data+'sync-events/'+notebook+'.json')).events;
for(const e of events) assert.ok(received.some(r=>JSON.stringify(r)===JSON.stringify(e)),'Move did not retain exact Pro provenance');
for(const p of pi.pages) assert.ok(mi.pages.some(r=>JSON.stringify(r)===JSON.stringify(p)),'Move canonical creation differs');
assert.equal(mv.sync,'Up to date'); assert.equal(mv.enabled,mi.enabled);
for(const host of [pro,move]) assert.equal(remote(host,'cat '+native),before[host],'native content changed during probe');
console.log(JSON.stringify({result:'actual-pro-to-hub-to-move-history-passed',proPages:ids(pro).length,movePages:ids(move).length,sharedPages:ids(pro).filter(id=>ids(move).includes(id)).length,proObservations:events.length,moveReceivedObservations:received.length,createdPages:mi.pages.length,proTracking:pv.enabled,moveTracking:mv.enabled,moveSync:mv.sync,nativeFilesUnchanged:true,physicalNewPageRoundTripVerified:false}));
