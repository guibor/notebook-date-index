// Execute the actual rollback gate against mocked unit/cgroup state. No device,
// systemd, real process signaling, sleeps, or file restoration is performed.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';

const cases = [
  ['stopped', true, true],
  ['empty-cgroup', true, true],
  ['not-found', true, true],
  ['commit-won', true, false],
  ['active-kill-failed', false, false],
  ['control-pid', false, false],
  ['populated-cgroup', false, false],
  ['collected-with-descendant', false, false],
  ['wrong-cgroup', false, false],
  ['unreadable-events', false, false],
  ['systemd-error', false, false],
  ['unknown-load', false, false],
  ['missing-cgroup-v2', false, false],
];
for (const file of ['ops/rollback-polish.sh', 'ops/rollback-move-polish.sh']) {
  const source = fs.readFileSync(file, 'utf8');
  const start = source.indexOf('# BEGIN installer-quiescence gate');
  const finish = source.indexOf('# END installer-quiescence gate');
  assert.ok(start >= 0 && finish > start);
  const gate = source.slice(start, finish);
  const unit = file.includes('-move-') ? 'dates-move-polish-install.service' : 'dates-polish-install.service';
  assert.match(gate, /for attempt in \$\(seq 1 20\)/);
  assert.ok(gate.indexOf('test "$quiescent" = 1') < gate.lastIndexOf('test ! -e "$rec/committed"'));
  assert.ok(finish < source.indexOf('for file in DatesPanel.qml DateTree.js; do'));
  for (const [scenario, success, restores] of cases) {
    const mocks = String.raw`
set -eu
scenario=$1
expected=$2
rec=/mock-recovery
committed=0
systemctl() {
  if [[ "$1" == kill ]]; then
    [[ "$2" == --kill-whom=all && "$3" == --signal=KILL && "$4" == "$expected" && "$#" == 4 ]] || exit 91
    if [[ "$scenario" == commit-won ]]; then committed=1; fi
    if [[ "$scenario" == active-kill-failed ]]; then return 1; fi
    return 0
  fi
  [[ "$1" == show && "$2" == "$expected" && "$3" == -p && "$5" == --value && "$#" == 5 ]] || exit 92
  [[ "$scenario" != systemd-error ]] || return 1
  case "$4" in
    LoadState)
      case "$scenario" in not-found|collected-with-descendant) echo not-found ;; unknown-load) echo masked ;; *) echo loaded ;; esac ;;
    ActiveState)
      case "$scenario" in active-kill-failed) echo active ;; not-found|collected-with-descendant) echo ;; *) echo failed ;; esac ;;
    MainPID)
      case "$scenario" in active-kill-failed) echo 42 ;; not-found|collected-with-descendant) echo ;; *) echo 0 ;; esac ;;
    ControlPID)
      case "$scenario" in control-pid) echo 43 ;; not-found|collected-with-descendant) echo ;; *) echo 0 ;; esac ;;
    ControlGroup)
      case "$scenario" in not-found|collected-with-descendant) echo ;; wrong-cgroup) echo /system.slice/other.service ;; *) echo "/system.slice/$expected" ;; esac ;;
    *) exit 93 ;;
  esac
}
test() {
  case "$*" in
    '-r /sys/fs/cgroup/unified/cgroup.controllers') [[ "$scenario" != missing-cgroup-v2 ]] ;;
    "! -e /sys/fs/cgroup/unified/system.slice/$expected")
      case "$scenario" in empty-cgroup|populated-cgroup|collected-with-descendant|unreadable-events) return 1 ;; *) return 0 ;; esac ;;
    "! -L /sys/fs/cgroup/unified/system.slice/$expected") return 0 ;;
    '! -e /mock-recovery/committed') [[ "$committed" == 0 ]] ;;
    '! -e /mock-recovery/rolled-back') return 0 ;;
    *) builtin test "$@" ;;
  esac
}
awk() {
  [[ "$2" == "/sys/fs/cgroup/unified/system.slice/$expected/cgroup.events" ]] || exit 94
  case "$scenario" in
    populated-cgroup|collected-with-descendant) echo 1 ;;
    unreadable-events) return 1 ;;
    *) echo 0 ;;
  esac
}
findmnt() {
  [[ "$*" == '-n -o FSTYPE /sys/fs/cgroup/unified' ]] || exit 96
  if [[ "$scenario" == missing-cgroup-v2 ]]; then echo cgroup; else echo cgroup2; fi
}
sleep() { [[ "$1" == 1 ]] || exit 95; }
`;
    const run = spawnSync('/bin/bash', ['-s', '--', scenario, unit], {
      input: mocks + '\n' + gate + '\nprintf "RESTORE_ALLOWED\\n"\n',
      encoding: 'utf8', timeout: 10000,
    });
    assert.equal(run.error, undefined, file + ': ' + scenario);
    assert.equal(run.status === 0, success, file + ': ' + scenario + '\n' + run.stderr);
    assert.equal(run.stdout.includes('RESTORE_ALLOWED'), restores, file + ': ' + scenario);
  }
}
for (const file of ['ops/install-polish.sh', 'ops/install-move-polish.sh', 'ops/rollback-polish.sh', 'ops/rollback-move-polish.sh']) {
  const source = fs.readFileSync(file, 'utf8');
  assert.doesNotMatch(source, /^systemctl is-active --quiet \S+ \S+/m, file + ' must check each service separately');
  if (file.includes('/install-')) {
    const mountGate = 'test "$(findmnt -n -o FSTYPE /sys/fs/cgroup/unified)" = cgroup2';
    const controllerGate = 'test -r /sys/fs/cgroup/unified/cgroup.controllers';
    assert.ok(source.includes(mountGate) && source.includes(controllerGate), file + ' must qualify rollback cgroup support');
    assert.ok(source.indexOf(mountGate) < source.indexOf('for file in DateTree.js DatesPanel.qml; do'));
  }
}
const move = fs.readFileSync('ops/install-move-polish.sh', 'utf8');
const owner = 'test "$(systemctl show dates-move-polish-install.service -p MainPID --value)" = "$$"';
assert.ok(move.includes(owner));
assert.ok(move.indexOf(owner) < move.indexOf('systemd-run --unit=dates-move-polish-rollback'));
console.log('Polish rollback quiescence and commit-race policy tests PASSED (26 mocked cases)');
