#!/bin/bash
# The eleven-QMD preimage is separately qualified; no old controller is relaxed.
set -euo pipefail
phase=${1:?prepare or activate}; stage=${2:?stage}; reviewed=${3:?manifest hash}
case "$stage" in /home/root/.codex-staging/dates-polish-*) ;; *) exit 2;; esac
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"; test -z "$(find "$stage" -type l)"
x=/home/root/xovi; q=$x/exthome/qt-resource-rebuilder; d=/home/root/.local/lib/notebook-date-index
data=/home/root/.local/share/notebook-date-index
rec=/home/root/.codex-backups/${stage##*/}
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
hash_is "$reviewed" "$stage/SHA256SUMS"; (cd "$stage" && sha256sum -c SHA256SUMS)
hash_is ffda5bd48b76895cbeca0073c9deb4222015b37951f148ff804ba89a848e007f "$stage/runtime.sha256"
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Ferrari'
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
test "$(cat /etc/version)" = 20260806095513
sha256sum -c "$stage/runtime.sha256"
for dir in "$d" "$data" "$q" /home/root/.codex-backups; do test "$(readlink -f "$dir")" = "$dir"; done
test -z "$(find "$d" "$q" -type l)"
expected_qmds=$(awk '$2 ~ /\.qmd$/ { print $2 }' "$stage/runtime.sha256" | LC_ALL=C sort)
test "$(find "$q" -name '*.qmd' | wc -l)" = 11
test "$(find "$q" -type f -name '*.qmd' | LC_ALL=C sort)" = "$expected_qmds"
extensions=("$x"/extensions.d/*.so); test "${#extensions[@]}" = 4
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
# Rollback proves descendants are gone using this qualified hybrid cgroup2 mount.
test "$(findmnt -n -o FSTYPE /sys/fs/cgroup/unified)" = cgroup2
test -r /sys/fs/cgroup/unified/cgroup.controllers
systemctl is-active --quiet xochitl
systemctl is-active --quiet notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(systemctl show notebook-date-index -p NRestarts --value)" = 0
for lock in /run/dispatch-appload-latency.lock /run/smart-remarkable-llm-button/deployment.lock /run/remarkable-beta-os-pro-bettertoc-upgrade.lock; do
  test ! -e "$lock"; test ! -L "$lock"
done
for unit in remagic-live-safety.timer remagic-live-safety.service dates-polish-rollback.timer; do
  if systemctl is-active --quiet "$unit"; then exit 2; fi
done
assert_ui() {
  local pid path
  pid=$(systemctl show xochitl -p MainPID --value)
  test "$pid" -gt 0
  test "$(readlink -f "/proc/$pid/exe")" = /usr/bin/xochitl
  for path in "$x/xovi.so" "${extensions[@]}"; do
    awk -v expected="$path" '$NF == expected { found=1 } END { exit !found }' "/proc/$pid/maps"
  done
}
assert_ui
snapshot() {
  sha256sum "$q"/*.qmd "$x"/extensions.d/*.so "$d/notebook-date-index"
  sha256sum /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum "$data/settings.json" "$data/token" "$data/sync.json"
  stat -c '%a %n' "$data/settings.json" "$data/token" "$data/sync.json"
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/{world,repositories}
  sha256sum /home/root/.local/lib/rmstream-shortcut/ScreenSharing.qml
  find "$x/exthome/appload" -type f -exec sha256sum '{}' \; | LC_ALL=C sort
  systemctl show notebook-date-index -p MainPID -p NRestarts -p ExecMainStartTimestampMonotonic -p FragmentPath
}
if [ "$phase" = prepare ]; then
  test ! -e "$rec"; mkdir -m 700 "$rec"
  cp -p "$d/DatesPanel.qml" "$d/DateTree.js" "$rec/"
  cp -p "$stage/rollback-polish.sh" "$stage/runtime.sha256" "$rec/"
  snapshot > "$rec/before.sha256"
  systemctl show notebook-date-index -p MainPID --value > "$rec/writer.pid"
  tar -czf "$rec/safety-backup.tgz" -C /home/root .local/lib/notebook-date-index .local/share/notebook-date-index .config/gestik.json .local/share/gestik-beta/gestik.json xovi/exthome/qt-resource-rebuilder
  chmod 600 "$rec/safety-backup.tgz"; touch "$rec/prepared"; sync
  sha256sum "$rec/safety-backup.tgz"; exit 0
fi
test "$phase" = activate
test "$(systemctl show dates-polish-install.service -p MainPID --value)" = "$$"
test -e "$rec/prepared"; test -e "$rec/mac-backup-verified"; test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
snapshot > "$rec/rechecked.sha256"; cmp "$rec/before.sha256" "$rec/rechecked.sha256"
cmp "$stage/rollback-polish.sh" "$rec/rollback-polish.sh"
hash_is 6ced2cd45df7513b0572b76a5f955cbdbc9d51ea4810a232511d5c362332944a "$rec/DatesPanel.qml"
hash_is a91dbdc403f9959490d879a1d52fb5bd2b683d020db2753b55127d678a0b09ce "$rec/DateTree.js"
systemd-run --unit=dates-polish-rollback --on-active=180 --timer-property=AccuracySec=1 bash "$rec/rollback-polish.sh" "$rec"
systemctl is-active --quiet dates-polish-rollback.timer
fail() { systemctl start --no-block dates-polish-rollback.service || true; }
trap fail EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
# Publish only external view files. No service, notebook, QMD or settings writes.
for file in DateTree.js DatesPanel.qml; do
  cp "$stage/$file" "$d/$file.polish-ready"; chmod 600 "$d/$file.polish-ready"
  cmp "$stage/$file" "$d/$file.polish-ready"; sync; mv "$d/$file.polish-ready" "$d/$file"
done
touch "$rec/activation-attempted"; sync
REMAGIC_SAMPLE_SECONDS=30 "$x/remagic-live-test-safe.sh"
snapshot > "$rec/after.sha256"; cmp "$rec/before.sha256" "$rec/after.sha256"
cmp "$stage/DatesPanel.qml" "$d/DatesPanel.qml"; cmp "$stage/DateTree.js" "$d/DateTree.js"
if grep -E '(DatesPanel\.qml|DateTree\.js):[0-9]+' /tmp/remagic-live-test.log; then exit 1; fi
if grep -Ei 'ReferenceError|TypeError|is not a type|Cannot assign|failed to load|Non-existent|Unexpected token' /tmp/remagic-live-test.log | grep -E 'Values.qml|Toolbar.qml|SettingsMenu.qml|ndi[A-Z]|ScreenSharing|rmstream|/appload/qml/window.qml'; then exit 1; fi
test "$(grep -Ec '\[qmldiff\]: Loading file [^ ]+\.qmd$' /tmp/remagic-live-test.log)" = 11
while read -r file; do
  test "$(grep -Fc "[qmldiff]: Loading file ${file##*/}" /tmp/remagic-live-test.log)" = 1
done <<< "$expected_qmds"
grep -Fq '[qmldiff]: Processing file /appload/qml/window.qml...' /tmp/remagic-live-test.log
if grep -Fq '[qmldiff]: Failed to load file' /tmp/remagic-live-test.log; then exit 1; fi
test "$(systemctl show xochitl -p NRestarts --value)" = 0
systemctl is-active --quiet xochitl
systemctl is-active --quiet notebook-date-index
assert_ui
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
pid=$(systemctl show xochitl -p MainPID --value)
printf 'mode=dates-polish\npid=%s\n' "$pid" > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
trap - EXIT HUP INT TERM
systemctl stop dates-polish-rollback.timer
cp /tmp/remagic-live-test.log "$rec/xochitl.log"
echo "dates_polish=passed pid=$pid recovery=$rec"
