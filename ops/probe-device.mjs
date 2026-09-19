// Read-only integration check of a real notebook. Never prints content or tokens.
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const [host,notebook]=process.argv.slice(2);
assert.match(host||'',/^\d+\.\d+\.\d+\.\d+$/);
assert.match(notebook||'',/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
const keys=execFileSync('ssh-keyscan',['-T','3','-t','ed25519',host],{stdio:['ignore','pipe','ignore']});
const fp=execFileSync('ssh-keygen',['-lf','-'],{input:keys,encoding:'utf8'}).trim().split(/\s+/)[1];
assert.equal(fp,'SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE');
const opts=['-o','BatchMode=yes','-o','PasswordAuthentication=no','-o','KbdInteractiveAuthentication=no','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5','-i',process.env.HOME+'/.ssh/id_ed25519_remarkable_new','root@'+host];
const remote=(cmd,input)=>execFileSync('ssh',[...opts,cmd],{input,encoding:'utf8',maxBuffer:32<<20,timeout:15000});
assert.equal(remote('cat /sys/devices/soc0/machine').trim(),'reMarkable Ferrari');
const native='/home/root/.local/share/remarkable/xochitl/'+notebook+'.content';
const before=remote('cat '+native);
const content=JSON.parse(before);
const records=content.cPages.pages.filter(p=>!p.deleted?.value);
const current=records.map(p=>p.id);
assert.ok(current.length>0);
const token='/home/root/.local/share/notebook-date-index/token';
function query(mode) {
 const body=JSON.stringify({notebook,current,mode});
 return JSON.parse(remote('/home/root/.vellum/bin/curl --fail --silent --max-time 8 -H "X-Date-Index-Token: $(cat '+token+')" -H "Content-Type: application/json;charset=UTF-8" --data-binary @- http://127.0.0.1:18742/v1/query',body));
}
const created=query('created'),modified=query('modified');
assert.equal(created.mode,'created'); assert.equal(modified.mode,'modified');
assert.equal(modified.warning,undefined); assert.equal(modified.estimated,0);
assert.ok(modified.groups.length>0,'real notebook modification dates missing');
const expected=records.filter(p=>typeof p.modifed==='string' && /^[0-9]+$/.test(p.modifed) && Number(p.modifed)>0);
assert.equal(modified.groups.reduce((n,g)=>n+g.pages.length,0),expected.length);
for(const group of modified.groups) for(const page of group.pages) {
 const record=records.find(p=>p.id===page.id);
 const day=new Intl.DateTimeFormat('en-CA',{timeZone:modified.timezone,year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(Number(record.modifed)));
 assert.equal(group.day,day);
 assert.equal(current[page.number-1],page.id);
}
const after=remote('cat '+native);
const hash=s=>createHash('sha256').update(s).digest('hex');
assert.equal(hash(before),hash(after),'native metadata changed during read-only probe; recheck if user was editing');
console.log(JSON.stringify({result:'real-notebook-read-only-probe-passed',currentPages:current.length,modifiedPages:expected.length,modifiedDays:modified.groups.length,createdDays:created.groups.length,tracking:created.enabled,timezone:modified.timezone,nativeFileUnchanged:true}));
