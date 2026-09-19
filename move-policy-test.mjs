import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import test from 'node:test';
import assert from 'node:assert/strict';
const hashes={
 'xovi-session-safe.sh':'c5f75ed51175e843704f774e5d37ea78963738ce6fe457d913aa07285438f172',
 'xovi-session-watchdog.sh':'6d510f3a90b8af418bd90683726b1e4a8275cd1097aba2a3f4e1a4d2c3dd5300',
 'xovi-session-dropins.sh':'90a04ab72b8ea93349393fc3150cc0ddd43cd2405d8eb73e26128c8cf93a3ff1'};
test('Move recovery machinery is identical to the independently qualified runtime',()=>{
 for(const [name,hash] of Object.entries(hashes)) {
  const file='ops/move-runtime/'+name;
  assert.equal(createHash('sha256').update(fs.readFileSync(file)).digest('hex'),hash);
  execFileSync('bash',['-n',file]);
 }
});
test('Dates Move parser accepts exactly its ten-QMD inventory',()=>{
 execFileSync('bash',['-e','-c','source ops/move-profile-lib.sh; load_exact_move_profile profiles/move-dates-r5.env']);
 const dir=fs.mkdtempSync('build/move-policy-');
 try {
  for(const count of [0,9,11]) {
   fs.writeFileSync(dir+'/bad.env',fs.readFileSync('profiles/move-dates-r5.env','utf8').replace('EXPECTED_QMD_COUNT=10','EXPECTED_QMD_COUNT='+count));
   assert.throws(()=>execFileSync('bash',['-e','-c','source ops/move-profile-lib.sh; load_exact_move_profile "$1"','_',dir+'/bad.env']));
  }
 } finally {fs.rmSync(dir,{recursive:true});}
});
