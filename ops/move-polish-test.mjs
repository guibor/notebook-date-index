// Offline fail-closed policy checks for the narrowly scoped Move panel update.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
const deploy=read('ops/deploy-move-polish.sh');
const install=read('ops/install-move-polish.sh');
const rollback=read('ops/rollback-move-polish.sh');
const canary=read('ops/qualify-move-polish-stock.mjs');
const digest=f=>createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex');
const assets={
 'profiles/move-dates-r5.env':'8353dceed76691313bfdda83dc679ca4488af0596daa3ff9dd76683fc84e7dac',
 'profiles/move-dates-r5-qmd.sha256':'188b7121d18e3c10913071ffa1d0abc3221039deeccc4d48e44d1815c7eea7a7',
 'ops/move-profile-lib.sh':'93f2b60bd8a47c60ff0ad326395975bd9f1ab1ef7f381fcdc0ad351d9f463cad',
 'ops/move-runtime/xovi-session-dropins.sh':'90a04ab72b8ea93349393fc3150cc0ddd43cd2405d8eb73e26128c8cf93a3ff1',
 'ops/move-runtime/xovi-session-watchdog.sh':'6d510f3a90b8af418bd90683726b1e4a8275cd1097aba2a3f4e1a4d2c3dd5300',
 'ops/move-runtime/xovi-session-safe.sh':'c5f75ed51175e843704f774e5d37ea78963738ce6fe457d913aa07285438f172'
};
for(const [file,hash] of Object.entries(assets)) {
 assert.equal(digest(file),hash,file+' changed');
 assert.ok(install.includes('hash_is '+hash+' '),'missing exact guard: '+file);
}
const before=(text,a,b)=>{
 const ai=text.indexOf(a),bi=text.indexOf(b);
 assert.ok(ai>=0&&bi>=0&&ai<bi,`${a} must precede ${b}`);
};
before(deploy,'ssh-keyscan','bash ops/run-move-session.sh');
before(deploy,'mac-backup-verified','"root@$host" deactivate');
before(deploy,'"root@$host" deactivate','node ops/qualify-move-polish-stock.mjs');
before(deploy,'node ops/qualify-move-polish-stock.mjs','--unit=dates-move-polish-install');
before(install,'systemctl is-active --quiet dates-move-polish-rollback.timer','for file in DateTree.js DatesPanel.qml; do');
before(install,'trap fail EXIT HUP INT TERM','for file in DateTree.js DatesPanel.qml; do');
before(rollback,'systemctl kill --kill-whom=all --signal=KILL dates-move-polish-install.service','for file in DatesPanel.qml DateTree.js; do');
assert.match(rollback,/touch "\$runtime\/deactivate\.request"/);
assert.match(rollback,/test ! -e "\$runtime\/recovery\.failed" \|\| exit 1/);
assert.match(install,/cmp "\$rec\/before\.sha256" "\$rec\/after\.sha256"/);
assert.match(install,/MainPID -p NRestarts -p InvocationID -p ExecMainStartTimestampMonotonic/);
assert.match(canary,/archive=rec\+'\/previous-canary'/);
assert.match(canary,/assert\.equal\(source\['canary\.sh'\]\.split\(old\)\.length,2\)/);
assert.match(canary,/16b73d17da803e3a22e235a7ae9d57487e83ac17bd1be0597576499b0f0c245c/);
for(const source of [deploy,install,rollback,canary]) {
 assert.doesNotMatch(source,/remagic-live-test|\/home\/root\/xovi\/stock|systemctl (?:stop|restart) notebook-date-index|mount -o|\/usr\/bin\/screenshot/);
}
assert.doesNotMatch(install,/cp .*\.qmd|mv .*\.qmd/);
assert.doesNotMatch(rollback,/tar -x|cp .*\$data|cp .*gestik/);
console.log('Move panel-polish exact-asset, transaction-order and preservation policy checks PASSED');
