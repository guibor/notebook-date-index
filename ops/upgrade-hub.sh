#!/bin/bash
set -euo pipefail
mode=${1:?upgrade or rollback}; stage=${2:?stage}; old=${3:?prior binary hash}; new=${4:?candidate hash}
case "$stage" in /home/mdf/.local/share/notebook-date-sync-staging/hub-*) ;; *) exit 2;; esac
[[ "$old" =~ ^[a-f0-9]{64}$ && "$new" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"
app=/home/mdf/.local/lib/notebook-date-sync/notebook-date-index
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
if [ "$mode" = rollback ]; then
  test ! -e "$stage/committed" || exit 0
  systemctl --user kill --kill-whom=all --signal=KILL notebook-date-sync-upgrade.service 2>/dev/null || true
  hash_is "$old" "$stage/prior-backend"
  current=$(sha256sum "$app" | cut -d' ' -f1)
  test "$current" = "$old" || test "$current" = "$new"
  systemctl --user stop notebook-date-sync.service
  install -m 700 "$stage/prior-backend" "$app.ready"
  mv "$app.ready" "$app"
  systemctl --user start notebook-date-sync.service
  touch "$stage/rolled-back"
  exit 0
fi
test "$mode" = upgrade
test ! -e "$stage/prior-backend"
hash_is "$old" "$app"; hash_is "$new" "$stage/notebook-date-index"
systemctl --user is-active --quiet notebook-date-sync.service
cp -p "$app" "$stage/prior-backend"
tar -czf "$stage/history-backup.tgz" -C /home/mdf/.local/share/notebook-date-sync history
chmod 600 "$stage/history-backup.tgz"
systemd-run --user --unit=notebook-date-sync-upgrade-rollback --on-active=90 --timer-property=AccuracySec=1 bash "$stage/upgrade-hub.sh" rollback "$stage" "$old" "$new"
systemctl --user is-active --quiet notebook-date-sync-upgrade-rollback.timer
fail() { systemctl --user start --no-block notebook-date-sync-upgrade-rollback.service || true; }
trap fail EXIT HUP INT TERM
systemctl --user stop notebook-date-sync.service
install -m 700 "$stage/notebook-date-index" "$app.ready"
mv "$app.ready" "$app"
systemctl --user start notebook-date-sync.service
sleep 2
node "$stage/smoke-hub.mjs"
hash_is "$new" "$app"
systemctl --user is-active --quiet notebook-date-sync.service
test "$(systemctl --user show notebook-date-sync.service -p NRestarts --value)" = 0
touch "$stage/committed"
trap - EXIT HUP INT TERM
systemctl --user stop notebook-date-sync-upgrade-rollback.timer
echo 'Dates hub upgrade and live HTTPS smoke test passed'
