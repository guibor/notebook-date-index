// Run on md-server. Credentials are read privately and never printed.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = '/home/mdf/.local/share/notebook-date-sync/credentials/';
const probe=JSON.parse(fs.readFileSync(root+'probe-client.json'));
const pro=JSON.parse(fs.readFileSync(root+'pro-client.json'));
const notebook='ffffffff-ffff-ffff-ffff-ffffffffffe0';
const page={id:'ffffffff-ffff-ffff-ffff-ffffffffffe1',utc:'2026-09-18T08:00:00Z',day:'2026-09-18',offset:180,timezone:'Asia/Jerusalem',estimated:true};
async function exchange(c,events,token=c.token) {
 const r=await fetch(c.endpoint,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json;charset=UTF-8','Authorization':'Bearer '+token,'X-Date-Device':c.device},body:JSON.stringify({notebook,events}),signal:AbortSignal.timeout(15000)});
 return {status:r.status,body:r.status===200?await r.json():null};
}
assert.equal((await exchange(probe,[],'invalid')).status,401);
assert.equal((await exchange(probe,[{device:'pro',page}])).status,403);
for(let i=0;i<3;i++) {
 const r=await exchange(probe,[{device:'probe',page}]);assert.equal(r.status,200);assert.equal(r.body.events.length,1);assert.deepEqual(r.body.events[0].page,page);
}
const read=await exchange(probe,[]);assert.equal(read.body.events.length,1);
const isolated=await exchange(pro,[]);assert.equal(isolated.status,200);assert.equal(isolated.body.events.length,0);
console.log('Live HTTPS authentication, estimate provenance, durable retry/read, and probe isolation PASSED (synthetic metadata only)');
