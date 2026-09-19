// Read-only verification: actual Pro history -> HTTPS hub -> Move credential.
// This does not claim that the physical Move has installed or received Dates.
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const [host,notebook]=process.argv.slice(2);
assert.match(host||'',/^\d+\.\d+\.\d+\.\d+$/);
assert.match(notebook||'',/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
const keys=execFileSync('ssh-keyscan',['-T','3','-t','ed25519',host],{stdio:['ignore','pipe','ignore']});
assert.equal(execFileSync('ssh-keygen',['-lf','-'],{input:keys,encoding:'utf8'}).trim().split(/\s+/)[1],'SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE');
const opts=['-o','BatchMode=yes','-o','PasswordAuthentication=no','-o','KbdInteractiveAuthentication=no','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5','-i',process.env.HOME+'/.ssh/id_ed25519_remarkable_new','root@'+host];
const remote=cmd=>execFileSync('ssh',[...opts,cmd],{encoding:'utf8',maxBuffer:16<<20,timeout:15000});
assert.equal(remote('cat /sys/devices/soc0/machine').trim(),'reMarkable Ferrari');
const data='/home/root/.local/share/notebook-date-index/';
const before=remote('cat '+data+notebook+'.json');
const index=JSON.parse(before), journal=JSON.parse(remote('cat '+data+'sync-events/'+notebook+'.json'));
assert.ok(index.pages.length>0,'choose a notebook with recorded creation dates');
const owned=journal.events.filter(e=>e.device==='pro');
assert.ok(owned.length>0);
const code=`import fs from 'node:fs';
const c=JSON.parse(fs.readFileSync('/home/mdf/.local/share/notebook-date-sync/credentials/move-client.json'));
const r=await fetch(c.endpoint,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json','Authorization':'Bearer '+c.token,'X-Date-Device':c.device},body:JSON.stringify({notebook:process.argv[2],events:[]}),signal:AbortSignal.timeout(15000)});
if(r.status!==200)throw Error('HTTPS read failed: '+r.status);
process.stdout.write(await r.text());`;
const response=JSON.parse(execFileSync('ssh',['-o','BatchMode=yes','md-server','node --input-type=module - '+notebook],{input:code,encoding:'utf8',maxBuffer:16<<20,timeout:25000}));
assert.equal(response.schema,1);
for(const event of owned) assert.ok(response.events.some(e=>JSON.stringify(e)===JSON.stringify(event)),'server/Move credential missing a Pro observation');
assert.equal(remote('cat '+data+notebook+'.json'),before,'history changed during check; repeat when stable');
console.log(JSON.stringify({result:'real-pro-history-delivered-through-hub',proObservations:owned.length,serverObservations:response.events.length,localPages:index.pages.length,trackingUnchanged:index.enabled,moveCredentialCanRead:true,physicalMoveVerified:false}));
