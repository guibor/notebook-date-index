#!/bin/bash
# Mac entry point: exact r5 -> r6 panel/helper, unchanged independently guarded Move.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
host=${1:?verified Move IP}; maintenance=${2:-../.worktrees/remarkable-beta-os-move-3280169}
[[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
keys=$(ssh-keyscan -T 3 -t ed25519 "$host" 2>/dev/null)
test "$(printf '%s\n' "$keys" | ssh-keygen -lf - | awk '{print $2}')" = SHA256:osLWO+xA0s/qhzWV2jtGWAF6NlD/KEi/d6CEkt8MZMk
opts=(-o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -i "$HOME/.ssh/id_ed25519_remarkable_new")
grep -q 'notebook-date-index offline gates PASSED' build/test.log
test "$(shasum -a 256 build/move-candidate/notebook-date-index.qmd | awk '{print $1}')" = f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0
# The current guard is itself checked read-only before staging or preparing anything.
bash ops/run-move-session.sh "root@$host" status
id=dates-move-polish-$(date -u +%Y%m%dT%H%M%SZ)-$$
stage=/home/root/.codex-staging/$id; rec=/home/root/.codex-backups/$id
localdir=.cache/$id
mkdir -m 700 "$localdir"
cp build/{DatesPanel.qml,DateTree.js} "$localdir/"
cp ops/{install-move-polish,rollback-move-polish}.sh "$localdir/"
cp profiles/move-dates-r5.env "$localdir/profile.env"
cp profiles/move-dates-r5-qmd.sha256 "$localdir/qmd-sha256.txt"
cp ops/move-profile-lib.sh "$localdir/profile-lib.sh"
cp ops/move-runtime/{xovi-session-dropins,xovi-session-watchdog,xovi-session-safe}.sh "$localdir/"
for script in "$localdir/"*.sh; do bash -n "$script"; done
(cd "$localdir" && shasum -a 256 *.qml *.js *.sh *.env *.txt > SHA256SUMS)
reviewed=$(shasum -a 256 "$localdir/SHA256SUMS" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "set -eu; test ! -e '$stage'; test ! -L '$stage'; mkdir -m 700 '$stage'"
scp -O -q "${opts[@]}" "$localdir/"* "root@$host:$stage/"
ssh "${opts[@]}" "root@$host" "bash '$stage/install-move-polish.sh' prepare '$stage' '$reviewed'"
scp -O -q "${opts[@]}" "root@$host:$rec/safety-backup.tgz" "$localdir/"
localhash=$(shasum -a 256 "$localdir/safety-backup.tgz" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "set -eu; test \"\$(sha256sum '$rec/safety-backup.tgz' | cut -d' ' -f1)\" = '$localhash'; touch '$rec/mac-backup-verified'; sync"
# Only the unchanged, qualified Move watchdog may transition back to stock.
bash ops/run-move-session.sh "root@$host" deactivate
node ops/qualify-move-polish-stock.mjs "$host" "$maintenance" "$id"
# Publication and activation share one device cgroup; rollback terminates it first.
ssh "${opts[@]}" "root@$host" "systemd-run --unit=dates-move-polish-install --collect --wait --pipe --property=Type=exec --property=KillMode=control-group --property=RuntimeMaxSec=480s /bin/bash '$stage/install-move-polish.sh' activate '$stage' '$reviewed'"
scp -O -q "${opts[@]}" "root@$host:$rec/committed" "root@$host:$rec/xochitl.log" "$localdir/"
bash ops/run-move-session.sh "root@$host" status
echo "deployment_evidence=$localdir"
