#!/bin/bash
# Exact one-time Pro v2 -> v3 payload upgrade. No QMD/notebook writes.
set -euo pipefail
phase=${1:?prepare or activate}; stage=${2:?stage}; reviewed=${3:?manifest hash}
case "$stage" in /home/root/.codex-staging/dates-v3-*) ;; *) exit 2;; esac
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"
test -z "$(find "$stage" -type l)"
x=/home/root/xovi; q=$x/exthome/qt-resource-rebuilder
d=/home/root/.local/lib/notebook-date-index
data=/home/root/.local/share/notebook-date-index
rec=/home/root/.codex-backups/${stage##*/}
test "$(sha256sum "$stage/SHA256SUMS" | cut -d' ' -f1)" = "$reviewed"
(cd "$stage" && sha256sum -c SHA256SUMS)
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Ferrari'
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
test "$(cat /etc/version)" = 20260806095513
sha256sum -c "$stage/pro-dates-v2-preimage.sha256"
(cd "$q" && sha256sum -c "$stage/base-eight.sha256")
extensions=("$x"/extensions.d/*.so); test "${#extensions[@]}" = 4
test "$(find "$q" -name '*.qmd' | wc -l)" = 10
for dir in "$x" "$q" "$d" "$data" /home/root/.codex-backups; do
  test "$(readlink -f "$dir")" = "$dir"; test "$(stat -c %u "$dir")" = 0
done
for file in "$d/notebook-date-index" "$d/DatesPanel.qml" "$data/settings.json" "$data/token"; do test ! -L "$file"; done
test ! -e "$d/DateTree.js"
# This exact preimage was local-only. Do not activate a new sync worker by accident.
test ! -e "$data/sync.json"
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
test "$(systemctl show xochitl -p NRestarts --value)" = 0
systemctl is-active --quiet xochitl notebook-date-index
test "$(pidof xochitl)" = "$(systemctl show xochitl -p MainPID --value)"
if systemctl show notebook-date-index -p ExecStart --value | grep -q -- --preview; then exit 2; fi
test -x /home/root/.vellum/bin/curl
test "$(df -Pk /home/root | awk 'NR==2 {print $4}')" -gt 100000
snapshot() {
  sha256sum "$q"/*.qmd "$x"/extensions.d/*.so
  sha256sum /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/world /home/root/.vellum/etc/apk/repositories
  sha256sum "$data/settings.json" "$data/token" /home/root/.local/lib/rmstream-shortcut/ScreenSharing.qml
  sha256sum "$x"/exthome/appload/rmstream/backend/entry "$x"/exthome/appload/rmstream/resources.rcc "$x"/exthome/appload/rmstream/manifest.json "$x"/exthome/appload/rmstream/icon.png
}
if [ "$phase" = prepare ]; then
  test ! -e "$rec"; mkdir -m 700 "$rec" "$rec/old"
  snapshot > "$rec/before.sha256"
  cp -p "$d/notebook-date-index" "$d/DatesPanel.qml" "$rec/old/"
  (cd "$rec/old" && sha256sum *) > "$rec/old.sha256"
  cp -p "$stage/rollback-dates-v3.sh" "$rec/rollback-dates-v3.sh"
  tar -czf "$rec/safety-backup.tgz" -C /home/root xovi/exthome/qt-resource-rebuilder .config/gestik.json .local/share/gestik-beta/gestik.json .local/share/notebook-date-index .local/lib/notebook-date-index
  chmod 600 "$rec/safety-backup.tgz"
  touch "$rec/prepared"; sync
  sha256sum "$rec/safety-backup.tgz"
  exit 0
fi
test "$phase" = activate
test -e "$rec/mac-backup-verified"; test -e "$rec/prepared"
test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
snapshot > "$rec/rechecked.sha256"; cmp "$rec/before.sha256" "$rec/rechecked.sha256"
(cd "$rec/old" && sha256sum -c "$rec/old.sha256")
cmp "$stage/rollback-dates-v3.sh" "$rec/rollback-dates-v3.sh"
if systemctl is-active --quiet dates-v3-rollback.timer; then exit 2; fi
systemd-run --unit=dates-v3-rollback --on-active=180 --timer-property=AccuracySec=1 bash "$rec/rollback-dates-v3.sh" "$rec"
systemctl is-active --quiet dates-v3-rollback.timer
fail() { systemctl start --no-block dates-v3-rollback.service || true; }
trap fail EXIT HUP INT TERM
systemctl stop notebook-date-index
# Consistent, latest private data preimage, in addition to the off-device archive.
tar -czf "$rec/data-at-activation.tgz" -C /home/root/.local/share notebook-date-index
chmod 600 "$rec/data-at-activation.tgz"
publish() {
  cp "$stage/$1" "$d/$1.v3-ready"; chmod "$2" "$d/$1.v3-ready"
  cmp "$stage/$1" "$d/$1.v3-ready"; sync; mv "$d/$1.v3-ready" "$d/$1"
}
publish DateTree.js 600
publish DatesPanel.qml 600
publish notebook-date-index 700
# The old writer is a collected transient unit: stopping it removes its unit.
systemd-run --unit=notebook-date-index --collect --property=Restart=on-failure --property=RestartSec=5 --property=MemoryMax=96M --property=NoNewPrivileges=yes "$d/notebook-date-index"
probe='{"notebook":"ffffffff-ffff-ffff-ffff-fffffffffff1","current":[],"mode":"modified"}'
for i in 1 2 3 4 5; do
  if /home/root/.vellum/bin/curl --fail --silent --max-time 3 -H "X-Date-Index-Token: $(cat "$data/token")" -H 'Content-Type: application/json;charset=UTF-8' --data "$probe" http://127.0.0.1:18742/v1/query > "$rec/health.json"; then break; fi
  sleep 1
done
grep -q '"mode":"modified"' "$rec/health.json"
grep -q '"timezone":"Asia/Jerusalem"' "$rec/health.json"
touch "$rec/activation-attempted"; sync
REMAGIC_SAMPLE_SECONDS=30 "$x/remagic-live-test-safe.sh"
snapshot > "$rec/after.sha256"; cmp "$rec/before.sha256" "$rec/after.sha256"
for file in notebook-date-index DatesPanel.qml DateTree.js; do cmp "$stage/$file" "$d/$file"; done
test "$(find "$q" -name '*.qmd' | wc -l)" = 10
grep -qF 'notebook-date-index.qmd' /tmp/remagic-live-test.log
grep -qF 'rmstream-shortcut.qmd' /tmp/remagic-live-test.log
if grep -Ei 'ReferenceError|TypeError|is not a type|Cannot assign|is not installed|failed to load|does not exist|No such file|Unexpected token' /tmp/remagic-live-test.log | grep -E 'DatesPanel|DateTree|Values.qml|rmstream|ScreenSharing'; then exit 1; fi
if grep -E '(DatesPanel\.qml|DateTree\.js):[0-9]+' /tmp/remagic-live-test.log; then exit 1; fi
systemctl is-active --quiet notebook-date-index xochitl
test "$(systemctl show notebook-date-index -p NRestarts --value)" = 0
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
test ! -e "$data/sync.json"
pid=$(systemctl show xochitl -p MainPID --value)
printf 'mode=dates-v3\npid=%s\n' "$pid" > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
trap - EXIT HUP INT TERM
systemctl stop dates-v3-rollback.timer
cp /tmp/remagic-live-test.log "$rec/xochitl.log"
echo "dates_v3=passed pid=$pid recovery=$rec"
