// Re-run the qualified harmless systemd experiment for the current stock PID.
// Only the two captured process-identity literals differ from its pinned source.
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const [host,maintenance]=process.argv.slice(2);
assert.match(host||'',/^\d+\.\d+\.\d+\.\d+$/); assert.ok(maintenance);
const hash=b=>createHash('sha256').update(b).digest('hex');
const keys=execFileSync('ssh-keyscan',['-T','3','-t','ed25519',host],{stdio:['ignore','pipe','ignore']});
assert.equal(execFileSync('ssh-keygen',['-lf','-'],{input:keys,encoding:'utf8'}).trim().split(/\s+/)[1],'SHA256:osLWO+xA0s/qhzWV2jtGWAF6NlD/KEi/d6CEkt8MZMk');
const opts=['-o','BatchMode=yes','-o','PasswordAuthentication=no','-o','KbdInteractiveAuthentication=no','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5','-i',process.env.HOME+'/.ssh/id_ed25519_remarkable_new'];
const remote=cmd=>execFileSync('ssh',[...opts,'root@'+host,cmd],{encoding:'utf8',timeout:110000});
const files={
 'canary.sh':['scripts/systemd-shadow-canary-safe.sh','16b73d17da803e3a22e235a7ae9d57487e83ac17bd1be0597576499b0f0c245c'],
 'profile.env':['profiles/move-3.28.0.169.env','3e14d9bf1b7eb0f02efc782876f6a5643674de66f8a71e8e77ae9ebc0e5f33ac'],
 'profile-lib.sh':['scripts/profile-lib.sh','c8f0f70002e2a72c15b71d1e935be2e31cc276799190d7197a28e7cea617e136']};
const source={};
for(const [name,[file,expected]] of Object.entries(files)) {
 source[name]=fs.readFileSync(path.join(maintenance,file),'utf8'); assert.equal(hash(source[name]),expected);
}
const identity=remote(`set -eu
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Chiappa'
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
systemctl is-active --quiet xochitl
pid=$(systemctl show xochitl -p MainPID --value)
if grep -q /home/root/xovi/ /proc/$pid/maps; then exit 1; fi
printf '%s ' "$pid"; awk '{print $22}' /proc/$pid/stat`).trim().split(/\s+/);
assert.equal(identity.length,2); identity.forEach(v=>assert.match(v,/^[1-9][0-9]*$/));
source['canary.sh']=source['canary.sh'].replace('EXPECTED_STOCK_PID=5492','EXPECTED_STOCK_PID='+identity[0]).replace('EXPECTED_STOCK_START=10491381','EXPECTED_STOCK_START='+identity[1]);
const id='dates-move-stock-check-'+Date.now();
const local=path.resolve('.cache',id),upload='/run/'+id;
fs.mkdirSync(local,{mode:0o700,recursive:true});
for(const [name,data] of Object.entries(source)) fs.writeFileSync(local+'/'+name,data,{mode:0o600});
const old='/run/remarkable-beta-os-systemd-shadow-canary',archive='/home/root/.codex-backups/dates-move-20260919-r5/previous-canary';
remote(`set -eu
test ! -e '${archive}'; test -d '${old}'; test ! -L '${old}'
test "$(find '${old}' -mindepth 1 -maxdepth 1 -type f | wc -l)" = 5
test "$(sha256sum '${old}/base-unit.saved' | cut -d' ' -f1)" = 29b8433458e94d199eb1a6244015dc968a9aa5f9dbfce0e27f3315527bf86901
test "$(sha256sum '${old}/base-dropin.saved' | cut -d' ' -f1)" = f1a7f632dd36401a795ca86a11579fa38100396c68bc40a5fb75f1d835806b1b
test "$(sha256sum '${old}/shadow-unit.saved' | cut -d' ' -f1)" = 2ac7d10983724dfc7d06e8cdca5edb5805c3f36c46b7cecadc2e4af302745b8f
test "$(sha256sum '${old}/shadow-dropin.saved' | cut -d' ' -f1)" = 68193778340971b3a9183cd0b0e81e623654d7ef6693c20f64c91f9c7505e87f
test "$(wc -l < '${old}/canary.passed')" = 8
mv '${old}' '${archive}'
mkdir -m 700 '${upload}'`);
for(const [name,data] of Object.entries(source)) {
 execFileSync('scp',['-O','-q',...opts,local+'/'+name,'root@'+host+':'+upload+'/'+name],{stdio:'inherit'});
 remote(`set -eu; test "$(sha256sum '${upload}/${name}' | cut -d' ' -f1)" = '${hash(data)}'; chmod 600 '${upload}/${name}'`);
}
const result=remote(`systemd-run --collect --wait --pipe --unit=dates-move-stock-check --property=Type=exec --property=KillMode=control-group --property=RuntimeMaxSec=90s --property=TimeoutStopSec=15s /usr/bin/env PROFILE='${upload}/profile.env' PROFILE_LIB='${upload}/profile-lib.sh' /bin/bash '${upload}/canary.sh'`);
fs.writeFileSync(local+'/result.log',result,{mode:0o600});
assert.match(result,/systemd_shadow_canary=passed/);
console.log('move_stock_check=passed stock_pid='+identity[0]+' evidence='+local);
