#!/bin/bash
set -euo pipefail
phase=${1:?prepare or activate}; stage=${2:?stage}; reviewed=${3:?manifest hash}; mode=${4:-preview}
case "$stage" in /home/root/.codex-staging/ndi-*) ;; *) exit 2;; esac
case "$mode" in preview|functional) ;; *) exit 2;; esac
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"
test -z "$(find "$stage" -type l)"
x=/home/root/xovi
qdir=$x/exthome/qt-resource-rebuilder
rec=/home/root/.codex-backups/${stage##*/}
payload=/home/root/.local/lib/notebook-date-index
data=/home/root/.local/share/notebook-date-index
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
snapshot() {
  (cd "$qdir" && sha256sum -c "$stage/co-resident.sha256") >&2
  sha256sum "$qdir"/*.qmd /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/world /home/root/.vellum/etc/apk/repositories
  sha256sum "$x"/extensions.d/*.so
}
hash_is "$reviewed" "$stage/SHA256SUMS"
(cd "$stage" && sha256sum -c SHA256SUMS)
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Ferrari'
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
hash_is 43a9d5d0acc5b998264c16586e11b848f3b83d2d63b5fd322b09c0977d94d3d4 /usr/bin/xochitl
hash_is d4df820c25c634c511de11067279d8310fa4f656dc52bd4540db6beac4ffd446 "$x/xovi.so"
hash_is 9a6d55d21852976e7c6cf34b1d09e5ca6e428547aa8c03d53d91b1bb9ff87b9a "$x/extensions.d/appload.so"
hash_is 61c0c7b0d4e2c7623147a87c63d6a4aaec868019e67fb0e1bdb1fcb215f6e155 "$x/extensions.d/xovi-message-broker.so"
hash_is 6726f561557406f36347e43fc2b44a88deef4fb273d2ece88f48f427dad8800f "$x/extensions.d/qt-resource-rebuilder.so"
hash_is 0a999dffbcb4026b59d6626a15360ef9388747448fdeeb97e4dab155425e3e1e "$x/extensions.d/framebuffer-spy.so"
# Count enabled visible libraries, not pre-existing macOS AppleDouble ._* metadata.
extensions=("$x"/extensions.d/*.so)
test "${#extensions[@]}" = 4
hash_is ecb0cfbd6828c374e48139064436a12f2c04778a90192b9dd85887edbdbe256a "$qdir/hashtab"
hash_is fb785d0f6a4efe3f58137b95fd979307cafa0d8d52e3e1d263d0f0df77ac81a7 "$x/remagic-live-test-safe.sh"
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test -x /home/root/.vellum/bin/curl
systemctl is-active --quiet xochitl
test "$(pidof xochitl)" = "$(systemctl show xochitl -p MainPID --value)"
for dir in "$x" "$qdir" /home/root/.local /home/root/.local/share /home/root/.codex-backups; do
  test "$(readlink -f "$dir")" = "$dir"
  test "$(stat -c %u "$dir")" = 0
done
if [ "$mode" = preview ]; then
  test ! -e "$qdir/notebook-date-index.qmd"
  test ! -e "$payload"; test ! -L "$payload"
  test ! -e "$data"; test ! -L "$data"
  test "$(find "$qdir" -name '*.qmd' | wc -l)" = 8
else
  # The caller supplies the physically accepted preview transaction, not just a flag.
  prior=${5:?accepted preview transaction required}
  case "$prior" in /home/root/.codex-backups/ndi-*) ;; *) exit 2;; esac
  test "$(readlink -f "$prior")" = "$prior"
  grep -qx 'mode=preview' "$prior/committed"
  hash_is "$(cat "$prior/candidate.sha256")" "$qdir/notebook-date-index.qmd"
  test "$(find "$qdir" -name '*.qmd' | wc -l)" = 9
  test "$(readlink -f "$payload")" = "$payload"
  test "$(readlink -f "$data")" = "$data"
  # Initial promotion never replaces a different backend binary or index schema.
  cmp "$stage/notebook-date-index" "$payload/notebook-date-index"
  prior_stage=/home/root/.codex-staging/${prior##*/}
  cmp "$prior_stage/DatesPanel.qml" "$payload/DatesPanel.qml"
fi
if [ "$phase" = prepare ]; then
  test ! -e "$rec"; mkdir -m 700 "$rec"
  snapshot > "$rec/before.sha256"
  cp -p "$stage/rollback-device.sh" "$rec/rollback-device.sh"
  if [ -f "$qdir/notebook-date-index.qmd" ]; then cp -p "$qdir/notebook-date-index.qmd" "$rec/prior.qmd"; fi
  if [ -f "$payload/DatesPanel.qml" ]; then cp -p "$payload/DatesPanel.qml" "$rec/prior-panel.qml"; fi
  backup_paths=(xovi/exthome/qt-resource-rebuilder .config/gestik.json .local/share/gestik-beta/gestik.json)
  if [ -d "$data" ]; then backup_paths+=(.local/share/notebook-date-index .local/lib/notebook-date-index); fi
  tar -czf "$rec/safety-backup.tgz" -C /home/root "${backup_paths[@]}"
  chmod 600 "$rec/safety-backup.tgz"
  sha256sum "$rec/safety-backup.tgz"
  touch "$rec/prepared"; sync
  echo "prepared=$rec"
  exit 0
fi
test "$phase" = activate
test -e "$rec/prepared"; test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
snapshot > "$rec/rechecked.sha256"
cmp "$rec/before.sha256" "$rec/rechecked.sha256"
cmp "$stage/rollback-device.sh" "$rec/rollback-device.sh"
test -e "$rec/mac-backup-verified"
if systemctl is-active --quiet notebook-date-index-rollback.timer; then exit 2; fi
systemd-run --unit=notebook-date-index-rollback --on-active=180 --timer-property=AccuracySec=1 "$rec/rollback-device.sh" "$rec"
systemctl is-active --quiet notebook-date-index-rollback.timer
fail() { systemctl start --no-block notebook-date-index-rollback.service || true; }
trap fail EXIT HUP INT TERM
if [ "$mode" = preview ]; then
  mkdir -p /home/root/.local/lib
  mkdir -m 700 "$payload" "$data"
  cp "$stage/notebook-date-index" "$payload/notebook-date-index"
  chmod 700 "$payload/notebook-date-index"
fi
cp "$stage/DatesPanel.qml" "$payload/DatesPanel.qml.ready"
chmod 600 "$payload/DatesPanel.qml.ready"
mv "$payload/DatesPanel.qml.ready" "$payload/DatesPanel.qml"
systemctl stop notebook-date-index.service 2>/dev/null || true
args=(); if [ "$mode" = preview ]; then args=(--preview); fi
systemd-run --unit=notebook-date-index --collect --property=Restart=on-failure --property=RestartSec=5 --property=MemoryMax=96M --property=NoNewPrivileges=yes "$payload/notebook-date-index" "${args[@]}"
for i in 1 2 3 4 5; do [ ! -f "$data/token" ] || break; sleep 1; done
systemctl is-active --quiet notebook-date-index
/home/root/.vellum/bin/curl -fsS --max-time 5 -H 'Content-Type: application/json' -H "X-Date-Index-Token: $(cat "$data/token")" -d '{"notebook":"00000000-0000-0000-0000-000000000000","current":[]}' http://127.0.0.1:18742/v1/query
cp "$stage/candidate.qmd" "$rec/candidate.ready"
sha256sum "$rec/candidate.ready" | cut -d' ' -f1 > "$rec/candidate.sha256"
sync
mv "$rec/candidate.ready" "$qdir/notebook-date-index.qmd"
sync
touch "$rec/activation-attempted"; sync
REMAGIC_SAMPLE_SECONDS=30 "$x/remagic-live-test-safe.sh"
snapshot > "$rec/after-with-date.sha256"
sed '\|/notebook-date-index.qmd$|d' "$rec/after-with-date.sha256" > "$rec/after-unrelated.sha256"
sed '\|/notebook-date-index.qmd$|d' "$rec/before.sha256" > "$rec/before-unrelated.sha256"
cmp "$rec/before-unrelated.sha256" "$rec/after-unrelated.sha256"
pid=$(systemctl show xochitl -p MainPID --value)
test "$(systemctl show xochitl -p NRestarts --value)" = 0
systemctl is-active --quiet notebook-date-index
grep -qF 'notebook-date-index.qmd' /tmp/remagic-live-test.log
if grep -Ei 'ReferenceError|TypeError|is not a type|Cannot assign|is not installed|notebook-date-index.*error' /tmp/remagic-live-test.log | grep -E 'ndi[A-Z]|DatesPanel|Values.qml|DocumentView.qml|AdditionalEditingToolsMenu.qml'; then exit 1; fi
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
printf 'mode=%s\npid=%s\n' "$mode" "$pid" > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
trap - EXIT HUP INT TERM
systemctl stop notebook-date-index-rollback.timer
cp /tmp/remagic-live-test.log "$rec/xochitl.log"
echo "notebook_date_index=$mode passed pid=$pid recovery=$rec"
