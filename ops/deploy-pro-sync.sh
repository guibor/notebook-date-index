#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
host=${1:?verified Pro IP}; config=${2:?private Pro client config}
[[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
test -f "$config"; test ! -L "$config"
node -e 'const c=JSON.parse(require("fs").readFileSync(process.argv[1])); if(c.device!=="pro" || !/^https:\/\//.test(c.endpoint) || !/^[a-f0-9]{64}$/.test(c.token)) process.exit(1)' "$config"
keys=$(ssh-keyscan -T 3 -t ed25519 "$host" 2>/dev/null)
test "$(printf '%s\n' "$keys" | ssh-keygen -lf - | awk '{print $2}')" = SHA256:dByHweKZkjDlZRBHdBisT5VD2kV85lClgtJExnDaTeE
opts=(-o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -i "$HOME/.ssh/id_ed25519_remarkable_new")
grep -q 'notebook-date-index offline gates PASSED' build/test.log
id=dates-sync-pro-$(date -u +%Y%m%dT%H%M%SZ)
stage=/home/root/.codex-staging/$id; rec=/home/root/.codex-backups/$id
localdir=.cache/$id
mkdir -m 700 "$localdir"
cp build/notebook-date-index ops/enable-pro-sync.sh "$localdir/"
cp "$config" "$localdir/sync.json"; chmod 600 "$localdir/sync.json"
cp profiles/co-resident.sha256 "$localdir/base-eight.sha256"
grep -v '/home/root/.local/lib/notebook-date-index/' profiles/pro-dates-v2-preimage.sha256 > "$localdir/runtime.sha256"
bash -n "$localdir/enable-pro-sync.sh"
(cd "$localdir" && shasum -a 256 notebook-date-index *.json *.sh *.sha256 > SHA256SUMS)
reviewed=$(shasum -a 256 "$localdir/SHA256SUMS" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "mkdir -m 700 '$stage'"
scp -O "${opts[@]}" "$localdir/"* "root@$host:$stage/"
ssh "${opts[@]}" "root@$host" "bash '$stage/enable-pro-sync.sh' prepare '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/safety-backup.tgz" "$localdir/"
localhash=$(shasum -a 256 "$localdir/safety-backup.tgz" | awk '{print $1}')
ssh "${opts[@]}" "root@$host" "test \"\$(sha256sum '$rec/safety-backup.tgz' | cut -d' ' -f1)\" = '$localhash'; touch '$rec/mac-backup-verified'"
ssh "${opts[@]}" "root@$host" "systemd-run --unit=dates-sync-pro-install --collect --wait --pipe --property=RuntimeMaxSec=100 bash '$stage/enable-pro-sync.sh' activate '$stage' '$reviewed'"
scp -O "${opts[@]}" "root@$host:$rec/committed" "$localdir/"
echo "deployment_evidence=$localdir"
