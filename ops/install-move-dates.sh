#!/bin/bash
# Dates-only first install on the separately qualified Chiappa .169 runtime.
set -euo pipefail
phase=${1:?prepare, publish or verify}; stage=${2:?stage}; reviewed=${3:?manifest hash}
case "$stage" in /home/root/.codex-staging/dates-move-20260919-r5) ;; *) exit 2;; esac
rec=/home/root/.codex-backups/dates-move-20260919-r5
d=/home/root/.local/lib/notebook-date-index; data=/home/root/.local/share/notebook-date-index
q=/home/root/xovi/exthome/qt-resource-rebuilder
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
test "$(readlink -f "$stage")" = "$stage"; test -z "$(find "$stage" -type l)"
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]; hash_is "$reviewed" "$stage/SHA256SUMS"
(cd "$stage" && sha256sum -c SHA256SUMS)
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Chiappa'
test "$(cat /etc/version)" = 20260806095513
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
hash_is 6361610111c381ce730a8bfcc889bd933ef5fef173563a9156e435233714e7ee /usr/bin/xochitl
hash_is d4df820c25c634c511de11067279d8310fa4f656dc52bd4540db6beac4ffd446 /home/root/xovi/xovi.so
hash_is a90138684bfc80defab2521d2a61073dbcbfc703dfdf08ee7573ab5047bf03c9 /home/root/xovi/extensions.d/qt-resource-rebuilder.so
hash_is 463e5544ba9be0cd6914f87f37e24e8c5f7db847ac7a847e603a43b59ab1fd88 "$q/hashtab"
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
systemctl is-active --quiet xochitl
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(readlink -f "$rec")" = "$rec"; test -e "$rec/mac-backup-verified"
snapshot() {
  (cd "$q" && sha256sum -c "$stage/base-nine.sha256") >&2
  sha256sum "$q"/*.qmd | sed '\|/notebook-date-index.qmd$|d'
  sha256sum /home/root/xovi/extensions.d/*.so /home/root/xovi/xovi.so "$q/hashtab"
  sha256sum /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/{world,repositories}
}
if [ "$phase" = prepare ]; then
  test ! -e "$d"; test ! -L "$d"; test ! -e "$data"; test ! -L "$data"
  test ! -e "$q/notebook-date-index.qmd"; test "$(find "$q" -name '*.qmd' | wc -l)" = 9
  snapshot > "$rec/before.sha256"
  cp -p "$stage/rollback-move-dates.sh" "$rec/"; touch "$rec/prepared"; sync; exit 0
fi
test -e "$rec/prepared"; test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
snapshot > "$rec/rechecked.sha256"; cmp "$rec/before.sha256" "$rec/rechecked.sha256"
if [ "$phase" = publish ]; then
  pid=$(systemctl show xochitl -p MainPID --value)
  if grep -q '/home/root/xovi/' "/proc/$pid/maps"; then exit 1; fi
  test ! -e /run/systemd/system.control/xochitl.service
  test ! -e /run/systemd/system.control/xochitl.service.d/xochitl-service-override.conf
  test ! -e "$d"; test ! -e "$data"; test ! -e "$q/notebook-date-index.qmd"
  cmp "$stage/rollback-move-dates.sh" "$rec/rollback-move-dates.sh"
  systemd-run --unit=dates-move-rollback --on-active=600 --timer-property=AccuracySec=1 bash "$rec/rollback-move-dates.sh" "$rec"
  systemctl is-active --quiet dates-move-rollback.timer
  mkdir -p /home/root/.local/lib
  mkdir -m 700 "$d" "$data"
  for file in notebook-date-index DatesPanel.qml DateTree.js; do
    cp "$stage/$file" "$d/$file.ready"; chmod 600 "$d/$file.ready"
    if [ "$file" = notebook-date-index ]; then chmod 700 "$d/$file.ready"; fi
    cmp "$stage/$file" "$d/$file.ready"; mv "$d/$file.ready" "$d/$file"
  done
  cp "$stage/sync.json" "$data/sync.json"; chmod 600 "$data/sync.json"
  systemd-run --unit=notebook-date-index --collect --property=Restart=on-failure --property=RestartSec=5 --property=MemoryMax=96M --property=NoNewPrivileges=yes "$d/notebook-date-index"
  ready=0
  for i in 1 2 3 4 5; do
    if [ -f "$data/token" ] && /home/root/.vellum/bin/curl -fsS --max-time 2 -H 'Content-Type: application/json;charset=UTF-8' -H "X-Date-Index-Token: $(cat "$data/token")" -d '{"notebook":"00000000-0000-0000-0000-000000000000","current":[]}' http://127.0.0.1:18742/v1/query > "$rec/service-health.json"; then ready=1; break; fi
    sleep 1
  done
  test "$ready" = 1
  cp "$stage/notebook-date-index.qmd" "$q/notebook-date-index.ready"
  chmod 600 "$q/notebook-date-index.ready"; sync; mv "$q/notebook-date-index.ready" "$q/notebook-date-index.qmd"; sync
  touch "$rec/published"; exit 0
fi
test "$phase" = verify; test -e "$rec/published"
(cd "$q" && sha256sum -c "$stage/ten-qmd.sha256")
test "$(find "$q" -name '*.qmd' | wc -l)" = 10
for file in notebook-date-index DatesPanel.qml DateTree.js; do cmp "$stage/$file" "$d/$file"; done
cmp "$stage/sync.json" "$data/sync.json"
systemctl is-active --quiet notebook-date-index remarkable-beta-os-xovi-session-watchdog
test "$(systemctl show notebook-date-index -p NRestarts --value)" = 0
log=/run/remarkable-beta-os-xovi-session/xochitl-activation.log
grep -q 'notebook-date-index.qmd' "$log"
if grep -E '(DatesPanel\.qml|DateTree\.js):[0-9]+|ReferenceError.*ndi[A-Z]|TypeError.*ndi[A-Z]|DocumentController is not defined' "$log"; then exit 1; fi
cp "$log" "$rec/xochitl.log"
printf 'mode=dates-move-r5\npid=%s\n' "$(systemctl show xochitl -p MainPID --value)" > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
systemctl stop dates-move-rollback.timer
echo 'dates_move_install=passed'
