#!/bin/bash
# Exact Pro r5 + accepted Dispatch QMD -> r6 panel/helper only.
# This is not an installer for a ten-QMD, Move, or different-firmware target.
set -euo pipefail
cd "$(dirname "$0")/.."
host=${1:?verified Pro IP}
[[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
keys=$(ssh-keyscan -T 3 -t ed25519 "$host" 2>/dev/null)
test "$(printf '%s\n' "$keys" | ssh-keygen -lf - | awk '{print $2}')" = SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE
opts=(-o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -i "$HOME/.ssh/id_ed25519_remarkable_new")
grep -q 'notebook-date-index offline gates PASSED' build/test.log
test "$(shasum -a 256 build/notebook-date-index.qmd | awk '{print $1}')" = 2d4681414ac00b534b2f21d179365601ce9e876c7cfbf6c6c8d25a2f8738e580
test "$(shasum -a 256 profiles/pro-dates-r5-dispatch-preimage.sha256 | awk '{print $1}')" = ffda5bd48b76895cbeca0073c9deb4222015b37951f148ff804ba89a848e007f
id=dates-polish-$(date -u +%Y%m%dT%H%M%SZ)
stage=/home/root/.codex-staging/$id; rec=/home/root/.codex-backups/$id
localdir=.cache/$id; mkdir -m 700 "$localdir"
cp build/{DatesPanel.qml,DateTree.js} "$localdir/"
cp profiles/pro-dates-r5-dispatch-preimage.sha256 "$localdir/runtime.sha256"
cp ops/{install-polish,rollback-polish}.sh "$localdir/"
for script in "$localdir/"*.sh; do bash -n "$script"; done
(cd "$localdir" && shasum -a 256 *.qml *.js *.sh *.sha256 > SHA256SUMS)
reviewed=$(shasum -a 256 "$localdir/SHA256SUMS" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "mkdir -m 700 '$stage'"
scp -O "${opts[@]}" "$localdir/"* "root@$host:$stage/"
ssh "${opts[@]}" "root@$host" "bash '$stage/install-polish.sh' prepare '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/safety-backup.tgz" "$localdir/"
chmod 600 "$localdir/safety-backup.tgz"
localhash=$(shasum -a 256 "$localdir/safety-backup.tgz" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "set -eu; test \"\$(sha256sum '$rec/safety-backup.tgz' | cut -d' ' -f1)\" = '$localhash'; touch '$rec/mac-backup-verified'; sync"
ssh "${opts[@]}" "root@$host" "systemd-run --unit=dates-polish-install --collect --wait --pipe --property=RuntimeMaxSec=150 bash '$stage/install-polish.sh' activate '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/committed" "root@$host:$rec/xochitl.log" "$localdir/"
echo "deployment_evidence=$localdir"
