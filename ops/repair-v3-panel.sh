#!/bin/bash
# Exact v3 external-panel correction; service, data, QMDs are not replaced.
set -euo pipefail
phase=${1:?prepare or activate}; stage=${2:?stage}; reviewed=${3:?manifest hash}
case "$stage" in /home/root/.codex-staging/dates-v3-panel-*) ;; *) exit 2;; esac
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"
test -z "$(find "$stage" -type l)"
x=/home/root/xovi; q=$x/exthome/qt-resource-rebuilder; d=/home/root/.local/lib/notebook-date-index
rec=/home/root/.codex-backups/${stage##*/}
test "$(sha256sum "$stage/SHA256SUMS" | cut -d' ' -f1)" = "$reviewed"
(cd "$stage" && sha256sum -c SHA256SUMS)
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Ferrari'
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
test "$(cat /etc/version)" = 20260806095513
sha256sum -c "$stage/runtime.sha256"
(cd "$q" && sha256sum -c "$stage/base-eight.sha256")
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
hash_is 3fb46a9ca713baf80e581ddd423b660fc45aefe97b7cc1ea9e21a22a95f959e0 "$d/notebook-date-index"
hash_is 340239c6fadf7ba761e30a7b77a02de2dd2aa4d21658a57e6575b8a30e93e2d3 "$d/DateTree.js"
hash_is dcbd9a48004e3a302eeb5bf746643e9520c59614807a8ce412184434b678c375 "$d/DatesPanel.qml"
for dir in "$d" "$q" /home/root/.codex-backups; do test "$(readlink -f "$dir")" = "$dir"; done
test ! -L "$d/DatesPanel.qml"
test "$(find "$q" -name '*.qmd' | wc -l)" = 10
extensions=("$x"/extensions.d/*.so); test "${#extensions[@]}" = 4
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
systemctl is-active --quiet xochitl notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
snapshot() {
  sha256sum "$q"/*.qmd "$x"/extensions.d/*.so "$d/notebook-date-index" "$d/DateTree.js"
  sha256sum /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum /home/root/.local/share/notebook-date-index/settings.json /home/root/.local/share/notebook-date-index/token
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/world /home/root/.vellum/etc/apk/repositories
  sha256sum /home/root/.local/lib/rmstream-shortcut/ScreenSharing.qml "$x"/exthome/appload/rmstream/backend/entry "$x"/exthome/appload/rmstream/resources.rcc
  systemctl show notebook-date-index -p MainPID -p NRestarts
}
if [ "$phase" = prepare ]; then
  test ! -e "$rec"; mkdir -m 700 "$rec"
  cp -p "$d/DatesPanel.qml" "$rec/old-panel.qml"
  cp -p "$stage/rollback-v3-panel.sh" "$rec/rollback-v3-panel.sh"
  snapshot > "$rec/before.sha256"
  tar -czf "$rec/safety-backup.tgz" -C /home/root .local/lib/notebook-date-index .local/share/notebook-date-index .config/gestik.json .local/share/gestik-beta/gestik.json xovi/exthome/qt-resource-rebuilder
  chmod 600 "$rec/safety-backup.tgz"
  touch "$rec/prepared"; sync
  sha256sum "$rec/safety-backup.tgz"
  exit 0
fi
test "$phase" = activate
test -e "$rec/prepared"; test -e "$rec/mac-backup-verified"; test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
snapshot > "$rec/rechecked.sha256"; cmp "$rec/before.sha256" "$rec/rechecked.sha256"
cmp "$stage/rollback-v3-panel.sh" "$rec/rollback-v3-panel.sh"
hash_is dcbd9a48004e3a302eeb5bf746643e9520c59614807a8ce412184434b678c375 "$rec/old-panel.qml"
if systemctl is-active --quiet dates-v3-panel-rollback.timer; then exit 2; fi
systemd-run --unit=dates-v3-panel-rollback --on-active=180 --timer-property=AccuracySec=1 bash "$rec/rollback-v3-panel.sh" "$rec"
systemctl is-active --quiet dates-v3-panel-rollback.timer
fail() { systemctl start --no-block dates-v3-panel-rollback.service || true; }
trap fail EXIT HUP INT TERM
cp "$stage/DatesPanel.qml" "$d/DatesPanel.qml.repair-ready"; chmod 600 "$d/DatesPanel.qml.repair-ready"
cmp "$stage/DatesPanel.qml" "$d/DatesPanel.qml.repair-ready"
sync; mv "$d/DatesPanel.qml.repair-ready" "$d/DatesPanel.qml"
touch "$rec/activation-attempted"; sync
REMAGIC_SAMPLE_SECONDS=30 "$x/remagic-live-test-safe.sh"
snapshot > "$rec/after.sha256"; cmp "$rec/before.sha256" "$rec/after.sha256"
cmp "$stage/DatesPanel.qml" "$d/DatesPanel.qml"
if grep -E '(DatesPanel\.qml|DateTree\.js):[0-9]+' /tmp/remagic-live-test.log; then exit 1; fi
if grep -Ei 'ReferenceError|TypeError|is not a type|Cannot assign|failed to load|Non-existent|Unexpected token' /tmp/remagic-live-test.log | grep -E 'Values.qml|ScreenSharing|rmstream'; then exit 1; fi
test "$(systemctl show xochitl -p NRestarts --value)" = 0
systemctl is-active --quiet xochitl notebook-date-index
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
pid=$(systemctl show xochitl -p MainPID --value)
printf 'mode=dates-v3-panel\npid=%s\n' "$pid" > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
trap - EXIT HUP INT TERM
systemctl stop dates-v3-panel-rollback.timer
cp /tmp/remagic-live-test.log "$rec/xochitl.log"
echo "dates_v3_panel=passed pid=$pid recovery=$rec"
