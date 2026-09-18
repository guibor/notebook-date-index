#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
host=${1:?verified candidate IP}; mode=${2:-preview}; accepted=${3:-}
[[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
case "$mode" in preview) artifact=build/notebook-date-index-preview.qmd;; refresh-preview|backend-preview) artifact=build/notebook-date-index-preview.qmd; test -n "$accepted";; functional) artifact=build/notebook-date-index.qmd; test -n "$accepted";; *) exit 2;; esac
if [ -n "$accepted" ]; then [[ "$accepted" =~ ^/home/root/\.codex-backups/ndi-[A-Za-z0-9-]+$ ]]; fi
mkdir -p .cache
chmod 700 .cache
keys=$(ssh-keyscan -T 3 -t ed25519 "$host" 2>/dev/null)
fingerprint=$(printf '%s\n' "$keys" | ssh-keygen -lf - | awk '{print $2}')
test "$fingerprint" = SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE
opts=(-o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -i "$HOME/.ssh/id_ed25519_remarkable_new")
id=ndi-$(date -u +%Y%m%dT%H%M%SZ)-$mode
stage=/home/root/.codex-staging/$id
rec=/home/root/.codex-backups/$id
localdir=.cache/$id
mkdir -m 700 "$localdir"
cp build/notebook-date-index "$localdir/notebook-date-index"
cp "$artifact" "$localdir/candidate.qmd"
if [ "$mode" != functional ]; then cp build/DatesPanel-preview.qml "$localdir/DatesPanel.qml"; else cp build/DatesPanel.qml "$localdir/DatesPanel.qml"; fi
cp ops/{install-device,rollback-device}.sh profiles/co-resident.sha256 "$localdir/"
(cd "$localdir" && shasum -a 256 notebook-date-index candidate.qmd DatesPanel.qml install-device.sh rollback-device.sh co-resident.sha256 > SHA256SUMS)
reviewed=$(shasum -a 256 "$localdir/SHA256SUMS" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "mkdir -m 700 '$stage'"
scp -O "${opts[@]}" "$localdir/"* "root@$host:$stage/"
ssh "${opts[@]}" "root@$host" "chmod 700 '$stage/'*.sh; bash '$stage/install-device.sh' prepare '$stage' '$reviewed' '$mode' '$accepted'"
scp -O "${opts[@]}" "root@$host:$rec/safety-backup.tgz" "$localdir/"
localhash=$(shasum -a 256 "$localdir/safety-backup.tgz" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "test \"\$(sha256sum '$rec/safety-backup.tgz' | cut -d' ' -f1)\" = '$localhash'; touch '$rec/mac-backup-verified'"
ssh "${opts[@]}" "root@$host" "systemd-run --unit=notebook-date-index-install --collect --wait --pipe --property=RuntimeMaxSec=150 bash '$stage/install-device.sh' activate '$stage' '$reviewed' '$mode' '$accepted'"
scp -O "${opts[@]}" "root@$host:$rec/committed" "root@$host:$rec/xochitl.log" "$localdir/"
echo "deployment_evidence=$localdir"
