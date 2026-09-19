#!/bin/bash
# Exact r5 -> r6 external panel/helper update; never replaces the Move runtime.
set -Eeuo pipefail
umask 077
phase=${1:?prepare or activate}; stage=${2:?stage}; reviewed=${3:?manifest hash}
id=${stage##*/}
[[ "$id" =~ ^dates-move-polish-[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]]
test "$stage" = "/home/root/.codex-staging/$id"
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
rec=/home/root/.codex-backups/$id
d=/home/root/.local/lib/notebook-date-index
data=/home/root/.local/share/notebook-date-index
x=/home/root/xovi; q=$x/exthome/qt-resource-rebuilder
runtime=/run/remarkable-beta-os-xovi-session
hash_is() { test -f "$2"; test ! -L "$2"; test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
test "$(readlink -f "$stage")" = "$stage"; test -z "$(find "$stage" -type l)"
hash_is "$reviewed" "$stage/SHA256SUMS"
(cd "$stage" && sha256sum -c SHA256SUMS)
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Chiappa'
test "$(cat /etc/version)" = 20260806095513
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
hash_is 6361610111c381ce730a8bfcc889bd933ef5fef173563a9156e435233714e7ee /usr/bin/xochitl
hash_is d4df820c25c634c511de11067279d8310fa4f656dc52bd4540db6beac4ffd446 "$x/xovi.so"
hash_is a90138684bfc80defab2521d2a61073dbcbfc703dfdf08ee7573ab5047bf03c9 "$x/extensions.d/qt-resource-rebuilder.so"
hash_is 463e5544ba9be0cd6914f87f37e24e8c5f7db847ac7a847e603a43b59ab1fd88 "$q/hashtab"
hash_is 445f532f18a7bf26d429aff0a481ab02ea3b74bef9b73f956f9b5ad77a09f979 "$d/notebook-date-index"
hash_is 6ced2cd45df7513b0572b76a5f955cbdbc9d51ea4810a232511d5c362332944a "$d/DatesPanel.qml"
hash_is a91dbdc403f9959490d879a1d52fb5bd2b683d020db2753b55127d678a0b09ce "$d/DateTree.js"
# These are the already-qualified ten-QMD Move recovery assets, byte-for-byte.
hash_is 8353dceed76691313bfdda83dc679ca4488af0596daa3ff9dd76683fc84e7dac "$stage/profile.env"
hash_is 188b7121d18e3c10913071ffa1d0abc3221039deeccc4d48e44d1815c7eea7a7 "$stage/qmd-sha256.txt"
hash_is 93f2b60bd8a47c60ff0ad326395975bd9f1ab1ef7f381fcdc0ad351d9f463cad "$stage/profile-lib.sh"
hash_is 90a04ab72b8ea93349393fc3150cc0ddd43cd2405d8eb73e26128c8cf93a3ff1 "$stage/xovi-session-dropins.sh"
hash_is 6d510f3a90b8af418bd90683726b1e4a8275cd1097aba2a3f4e1a4d2c3dd5300 "$stage/xovi-session-watchdog.sh"
hash_is c5f75ed51175e843704f774e5d37ea78963738ce6fe457d913aa07285438f172 "$stage/xovi-session-safe.sh"
(cd "$q" && sha256sum -c "$stage/qmd-sha256.txt")
test "$(find "$q" -name '*.qmd' | wc -l)" = 10
extensions=("$x"/extensions.d/*.so); test "${#extensions[@]}" = 1
for dir in "$d" "$data" "$q" /home/root/.codex-backups; do test "$(readlink -f "$dir")" = "$dir"; done
test -z "$(find "$d" "$data" -type l)"
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
# Rollback proves descendants are gone using this qualified hybrid cgroup2 mount.
test "$(findmnt -n -o FSTYPE /sys/fs/cgroup/unified)" = cgroup2
test -r /sys/fs/cgroup/unified/cgroup.controllers
systemctl is-active --quiet xochitl
systemctl is-active --quiet notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(systemctl show notebook-date-index -p NRestarts --value)" = 0
snapshot() {
  sha256sum "$q"/*.qmd "$x"/extensions.d/*.so "$x/xovi.so" "$q/hashtab" "$d/notebook-date-index"
  sha256sum /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum "$data/settings.json" "$data/token" "$data/sync.json"
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/world /home/root/.vellum/etc/apk/repositories
  systemctl show notebook-date-index -p MainPID -p NRestarts -p InvocationID -p ExecMainStartTimestampMonotonic
}
if [ "$phase" = prepare ]; then
  systemctl is-active --quiet remarkable-beta-os-xovi-session-watchdog
  test ! -e "$rec"; test ! -L "$rec"; mkdir -m 700 "$rec"
  for file in profile.env profile-lib.sh xovi-session-dropins.sh xovi-session-watchdog.sh xovi-session-safe.sh qmd-sha256.txt; do cmp "$stage/$file" "$runtime/$file"; done
  cp -p "$d/DatesPanel.qml" "$d/DateTree.js" "$rec/"
  cp -p "$stage/rollback-move-polish.sh" "$rec/"
  snapshot > "$rec/before.sha256"
  # Never restore this data snapshot over later observations; it is recovery evidence.
  tar -czf "$rec/safety-backup.tgz" -C / home/root/.local/lib/notebook-date-index home/root/.local/share/notebook-date-index home/root/.config/gestik.json home/root/.local/share/gestik-beta/gestik.json home/root/xovi/exthome/qt-resource-rebuilder home/root/.vellum/lib/apk/db/installed home/root/.vellum/etc/apk/world home/root/.vellum/etc/apk/repositories run/remarkable-beta-os-xovi-session run/remarkable-beta-os-systemd-shadow-canary
  chmod 600 "$rec/safety-backup.tgz"
  touch "$rec/prepared"; sync; sha256sum "$rec/safety-backup.tgz"; exit 0
fi
test "$phase" = activate
test "$(systemctl show dates-move-polish-install.service -p MainPID --value)" = "$$"
test "$(readlink -f "$rec")" = "$rec"
test -e "$rec/prepared"; test -e "$rec/mac-backup-verified"
test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
test -e "$rec/canary-verified"
snapshot > "$rec/rechecked.sha256"; cmp "$rec/before.sha256" "$rec/rechecked.sha256"
cmp "$stage/rollback-move-polish.sh" "$rec/rollback-move-polish.sh"
pid=$(systemctl show xochitl -p MainPID --value)
if grep -q /home/root/xovi/ "/proc/$pid/maps"; then exit 1; fi
test ! -e "$runtime"; test ! -L "$runtime"
test ! -e /run/systemd/system.control/xochitl.service
test ! -e /run/systemd/system.control/xochitl.service.d/xochitl-service-override.conf
if systemctl is-active --quiet dates-move-polish-rollback.timer; then exit 2; fi
systemd-run --unit=dates-move-polish-rollback --on-active=600 --timer-property=AccuracySec=1 /bin/bash "$rec/rollback-move-polish.sh" "$rec"
systemctl is-active --quiet dates-move-polish-rollback.timer
fail() { systemctl start --no-block dates-move-polish-rollback.service || true; }
trap fail EXIT HUP INT TERM
# No native documents, history, service process, QMDs or device settings are written.
for file in DateTree.js DatesPanel.qml; do
  cp "$stage/$file" "$d/$file.polish-ready"; chmod 600 "$d/$file.polish-ready"
  cmp "$stage/$file" "$d/$file.polish-ready"; sync; mv "$d/$file.polish-ready" "$d/$file"
done
mkdir -m 700 "$runtime"
for file in profile.env profile-lib.sh xovi-session-dropins.sh xovi-session-watchdog.sh xovi-session-safe.sh qmd-sha256.txt; do
  cp "$stage/$file" "$runtime/$file"; chmod 600 "$runtime/$file"; cmp "$stage/$file" "$runtime/$file"
done
chmod 700 "$runtime/xovi-session-watchdog.sh" "$runtime/xovi-session-safe.sh"
touch "$rec/activation-attempted"; sync
PROFILE="$runtime/profile.env" PROFILE_LIB="$runtime/profile-lib.sh" DROPIN_LIB="$runtime/xovi-session-dropins.sh" WATCHDOG_SCRIPT="$runtime/xovi-session-watchdog.sh" QMD_MANIFEST="$runtime/qmd-sha256.txt" /bin/bash "$runtime/xovi-session-safe.sh" activate
snapshot > "$rec/after.sha256"; cmp "$rec/before.sha256" "$rec/after.sha256"
cmp "$stage/DatesPanel.qml" "$d/DatesPanel.qml"; cmp "$stage/DateTree.js" "$d/DateTree.js"
systemctl is-active --quiet xochitl
systemctl is-active --quiet notebook-date-index
systemctl is-active --quiet remarkable-beta-os-xovi-session-watchdog
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
log="$runtime/xochitl-activation.log"
grep -q 'notebook-date-index.qmd' "$log"
if grep -E '(DatesPanel\.qml|DateTree\.js):[0-9]+|ReferenceError.*ndi[A-Z]|TypeError.*ndi[A-Z]|DocumentController is not defined' "$log"; then exit 1; fi
cp "$log" "$rec/xochitl.log"
printf 'mode=dates-move-polish-r6\npid=%s\n' "$(systemctl show xochitl -p MainPID --value)" > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
trap - EXIT HUP INT TERM
systemctl stop dates-move-polish-rollback.timer
echo "dates_move_polish=passed recovery=$rec"
