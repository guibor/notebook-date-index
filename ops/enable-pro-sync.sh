#!/bin/bash
# Service-only Pro upgrade. Never restart xochitl or restore Dates history.
set -euo pipefail
phase=${1:?prepare activate or rollback}; stage=${2:?stage}; reviewed=${3:?manifest hash}
case "$stage" in /home/root/.codex-staging/dates-sync-pro-*) ;; *) exit 2;; esac
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"
test -z "$(find "$stage" -type l)"
test "$(sha256sum "$stage/SHA256SUMS" | cut -d' ' -f1)" = "$reviewed"
(cd "$stage" && sha256sum -c SHA256SUMS)
rec=/home/root/.codex-backups/${stage##*/}
d=/home/root/.local/lib/notebook-date-index
data=/home/root/.local/share/notebook-date-index
app=$d/notebook-date-index
old=3fb46a9ca713baf80e581ddd423b660fc45aefe97b7cc1ea9e21a22a95f959e0
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
start_writer() {
  systemd-run --unit=notebook-date-index --collect --property=Restart=on-failure --property=RestartSec=5 --property=MemoryMax=96M --property=NoNewPrivileges=yes "$app"
}
stop_writer() {
  if systemctl is-active --quiet notebook-date-index; then systemctl stop notebook-date-index; fi
  if pidof notebook-date-index >/dev/null; then exit 1; fi
}
if [ "$phase" = rollback ]; then
  test -e "$rec/prepared"
  test ! -e "$rec/committed" || exit 0
  test ! -e "$rec/rolled-back" || exit 0
  systemctl kill --kill-whom=all --signal=KILL dates-sync-pro-install.service 2>/dev/null || true
  hash_is "$old" "$rec/prior-backend"
  stop_writer
  if [ -e "$data/sync.json" ]; then
    cmp "$stage/sync.json" "$data/sync.json"
    mv "$data/sync.json" "$rec/disabled-sync.json"
  fi
  cp -p "$rec/prior-backend" "$app.rollback-ready"
  sync; mv "$app.rollback-ready" "$app"; sync
  start_writer
  systemctl is-active --quiet notebook-date-index xochitl
  touch "$rec/rolled-back"
  exit 0
fi
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Ferrari'
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
test "$(cat /etc/version)" = 20260806095513
sha256sum -c "$stage/runtime.sha256"
(cd /home/root/xovi/exthome/qt-resource-rebuilder && sha256sum -c "$stage/base-eight.sha256")
hash_is "$old" "$app"
hash_is 8339b3c6b39363a88e2994f6604693890bf210cf7a0ecb3c2c38b53417cd090b "$d/DatesPanel.qml"
hash_is f37b64247f098c933f3dafe8978f0bc82ca7afda890b8b0f4c7fdcdeedd693e6 "$d/DateTree.js"
for dir in "$d" "$data" /home/root/.codex-backups; do test "$(readlink -f "$dir")" = "$dir"; done
test -z "$(find "$d" "$data" -type l)"
test ! -e "$data/sync.json"
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
systemctl is-active --quiet xochitl notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
snapshot() {
  sha256sum /usr/bin/xochitl "$d/DatesPanel.qml" "$d/DateTree.js" /home/root/xovi/exthome/qt-resource-rebuilder/*.qmd /home/root/xovi/extensions.d/*.so
  sha256sum /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json "$data/settings.json" "$data/token"
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/world /home/root/.vellum/etc/apk/repositories
  systemctl show xochitl -p MainPID -p NRestarts
}
if [ "$phase" = prepare ]; then
  test ! -e "$rec"; mkdir -m 700 "$rec"
  cp -p "$app" "$rec/prior-backend"
  snapshot > "$rec/before.sha256"
  tar -czf "$rec/safety-backup.tgz" -C /home/root .local/lib/notebook-date-index .local/share/notebook-date-index
  chmod 600 "$rec/safety-backup.tgz"
  touch "$rec/prepared"; sync
  sha256sum "$rec/safety-backup.tgz"
  exit 0
fi
test "$phase" = activate
test -e "$rec/prepared"; test -e "$rec/mac-backup-verified"; test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
snapshot > "$rec/rechecked.sha256"; cmp "$rec/before.sha256" "$rec/rechecked.sha256"
if systemctl is-active --quiet dates-sync-pro-rollback.timer; then exit 2; fi
systemd-run --unit=dates-sync-pro-rollback --on-active=150 --timer-property=AccuracySec=1 bash "$stage/enable-pro-sync.sh" rollback "$stage" "$reviewed"
systemctl is-active --quiet dates-sync-pro-rollback.timer
fail() { systemctl start --no-block dates-sync-pro-rollback.service || true; }
trap fail EXIT HUP INT TERM
stop_writer
cp "$stage/notebook-date-index" "$app.sync-ready"; chmod 700 "$app.sync-ready"
cmp "$stage/notebook-date-index" "$app.sync-ready"
cp "$stage/sync.json" "$data/sync.json.ready"; chmod 600 "$data/sync.json.ready"
cmp "$stage/sync.json" "$data/sync.json.ready"
sync; mv "$data/sync.json.ready" "$data/sync.json"; mv "$app.sync-ready" "$app"; sync
start_writer
sleep 3
systemctl is-active --quiet notebook-date-index
test "$(systemctl show notebook-date-index -p NRestarts --value)" = 0
/home/root/.vellum/bin/curl --fail --silent --max-time 8 -H "X-Date-Index-Token: $(cat "$data/token")" -H 'Content-Type: application/json;charset=UTF-8' --data '{"notebook":"ffffffff-ffff-ffff-ffff-ffffffffffd0","current":[]}' http://127.0.0.1:18742/v1/query | grep -q '"groups"'
sleep 12
test "$(systemctl show notebook-date-index -p NRestarts --value)" = 0
snapshot > "$rec/after.sha256"; cmp "$rec/before.sha256" "$rec/after.sha256"
cmp "$stage/notebook-date-index" "$app"; cmp "$stage/sync.json" "$data/sync.json"
test "$(stat -c %a "$data/sync.json")" = 600
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
systemctl show xochitl notebook-date-index -p MainPID -p NRestarts > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
trap - EXIT HUP INT TERM
systemctl stop dates-sync-pro-rollback.timer
echo "dates_sync_pro=service_installed recovery=$rec"
