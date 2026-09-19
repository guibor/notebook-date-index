#!/bin/bash
# Exact Pro revision 4 -> 5, retaining the running writer and all private data.
set -euo pipefail
cd "$(dirname "$0")/.."
host=${1:?verified Pro IP}
[[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
keys=$(ssh-keyscan -T 3 -t ed25519 "$host" 2>/dev/null)
test "$(printf '%s\n' "$keys" | ssh-keygen -lf - | awk '{print $2}')" = SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE
opts=(-o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -i "$HOME/.ssh/id_ed25519_remarkable_new")
grep -q 'notebook-date-index offline gates PASSED' build/test.log
id=dates-navigation-$(date -u +%Y%m%dT%H%M%SZ)
stage=/home/root/.codex-staging/$id; rec=/home/root/.codex-backups/$id
localdir=.cache/$id; mkdir -m 700 "$localdir"
cp build/{DatesPanel.qml,DateTree.js,notebook-date-index.qmd} "$localdir/"
cp profiles/co-resident.sha256 "$localdir/base-eight.sha256"
grep -v -E '/home/root/.local/lib/notebook-date-index/|/notebook-date-index.qmd$' profiles/pro-dates-v2-preimage.sha256 > "$localdir/runtime.sha256"
cp ops/{install-navigation,rollback-navigation}.sh "$localdir/"
for script in "$localdir/"*.sh; do bash -n "$script"; done
(cd "$localdir" && shasum -a 256 *.qml *.js *.qmd *.sh *.sha256 > SHA256SUMS)
reviewed=$(shasum -a 256 "$localdir/SHA256SUMS" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "mkdir -m 700 '$stage'"
scp -O "${opts[@]}" "$localdir/"* "root@$host:$stage/"
ssh "${opts[@]}" "root@$host" "bash '$stage/install-navigation.sh' prepare '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/safety-backup.tgz" "$localdir/"
localhash=$(shasum -a 256 "$localdir/safety-backup.tgz" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "test \"\$(sha256sum '$rec/safety-backup.tgz' | cut -d' ' -f1)\" = '$localhash'; touch '$rec/mac-backup-verified'"
ssh "${opts[@]}" "root@$host" "systemd-run --unit=dates-navigation-install --collect --wait --pipe --property=RuntimeMaxSec=150 bash '$stage/install-navigation.sh' activate '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/committed" "root@$host:$rec/xochitl.log" "$localdir/"
echo "deployment_evidence=$localdir"
