#!/bin/bash
# Owner-specific md-server binary-only upgrade; not a generic installer.
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'notebook-date-index offline gates PASSED' build/test.log
old=4628886cdbd5c604d348e596df295ccd96158a9a187507445d05f60c32a89eff
new=$(shasum -a 256 build/notebook-date-index-hub | awk '{print $1}')
id=hub-estimates-$(date -u +%Y%m%dT%H%M%SZ)
stage=/home/mdf/.local/share/notebook-date-sync-staging/$id
localdir=.cache/$id
mkdir -m 700 "$localdir"
cp build/notebook-date-index-hub "$localdir/notebook-date-index"
cp ops/{upgrade-hub.sh,smoke-hub.mjs} "$localdir/"
(cd "$localdir" && shasum -a 256 notebook-date-index *.sh *.mjs > SHA256SUMS)
reviewed=$(shasum -a 256 "$localdir/SHA256SUMS" | awk '{print $1}')
ssh -o BatchMode=yes md-server "test \"\$(sha256sum /home/mdf/.local/lib/notebook-date-sync/notebook-date-index | cut -d' ' -f1)\" = '$old'; mkdir -m 700 '$stage'"
scp -q "$localdir/"* "md-server:$stage/"
ssh -o BatchMode=yes md-server "test \"\$(sha256sum '$stage/SHA256SUMS' | cut -d' ' -f1)\" = '$reviewed'; cd '$stage'; sha256sum -c SHA256SUMS; systemd-run --user --unit=notebook-date-sync-upgrade --collect --wait --pipe --property=RuntimeMaxSec=75 bash '$stage/upgrade-hub.sh' upgrade '$stage' '$old' '$new'"
scp -q "md-server:$stage/history-backup.tgz" "md-server:$stage/prior-backend" "md-server:$stage/committed" "$localdir/"
chmod 600 "$localdir/history-backup.tgz" "$localdir/prior-backend"
echo "hub_evidence=$localdir"
