#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
host=${1:?verified Pro IP}
[[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
keys=$(ssh-keyscan -T 3 -t ed25519 "$host" 2>/dev/null)
test "$(printf '%s\n' "$keys" | ssh-keygen -lf - | awk '{print $2}')" = SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE
opts=(-o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -i "$HOME/.ssh/id_ed25519_remarkable_new")
test "$(shasum -a 256 build/notebook-date-index.qmd | awk '{print $1}')" = f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0
grep -q 'notebook-date-index offline gates PASSED' build/test.log
id=dates-v3-$(date -u +%Y%m%dT%H%M%SZ)
stage=/home/root/.codex-staging/$id; rec=/home/root/.codex-backups/$id
localdir=.cache/$id
mkdir -p "$localdir"; chmod 700 .cache "$localdir"
cp build/notebook-date-index build/DatesPanel.qml build/DateTree.js "$localdir/"
cp profiles/pro-dates-v2-preimage.sha256 "$localdir/"
cp profiles/co-resident.sha256 "$localdir/base-eight.sha256"
cp ops/{upgrade-dates-v3,rollback-dates-v3}.sh "$localdir/"
for script in "$localdir/"*.sh; do bash -n "$script"; done
(cd "$localdir" && shasum -a 256 notebook-date-index *.qml *.js *.sh *.sha256 > SHA256SUMS)
reviewed=$(shasum -a 256 "$localdir/SHA256SUMS" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "mkdir -m 700 '$stage'"
scp -O "${opts[@]}" "$localdir/"* "root@$host:$stage/"
ssh "${opts[@]}" "root@$host" "bash '$stage/upgrade-dates-v3.sh' prepare '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/safety-backup.tgz" "$localdir/"
localhash=$(shasum -a 256 "$localdir/safety-backup.tgz" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "test \"\$(sha256sum '$rec/safety-backup.tgz' | cut -d' ' -f1)\" = '$localhash'; touch '$rec/mac-backup-verified'"
ssh "${opts[@]}" "root@$host" "systemd-run --unit=dates-v3-install --collect --wait --pipe --property=RuntimeMaxSec=150 bash '$stage/upgrade-dates-v3.sh' activate '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/committed" "root@$host:$rec/xochitl.log" "root@$host:$rec/data-at-activation.tgz" "$localdir/"
echo "deployment_evidence=$localdir"
