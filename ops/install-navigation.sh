#!/bin/bash
set -euo pipefail
phase=${1:?prepare or activate}; stage=${2:?stage}; reviewed=${3:?manifest hash}
case "$stage" in /home/root/.codex-staging/dates-navigation-*) ;; *) exit 2;; esac
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"; test -z "$(find "$stage" -type l)"
x=/home/root/xovi; q=$x/exthome/qt-resource-rebuilder; d=/home/root/.local/lib/notebook-date-index
rec=/home/root/.codex-backups/${stage##*/}
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
hash_is "$reviewed" "$stage/SHA256SUMS"; (cd "$stage" && sha256sum -c SHA256SUMS)
test "$(cat /sys/devices/soc0/machine)" = 'reMarkable Ferrari'
grep -qx 'IMG_VERSION="3.28.0.169"' /etc/os-release
test "$(cat /etc/version)" = 20260806095513
sha256sum -c "$stage/runtime.sha256"; (cd "$q" && sha256sum -c "$stage/base-eight.sha256")
hash_is 445f532f18a7bf26d429aff0a481ab02ea3b74bef9b73f956f9b5ad77a09f979 "$d/notebook-date-index"
hash_is f37b64247f098c933f3dafe8978f0bc82ca7afda890b8b0f4c7fdcdeedd693e6 "$d/DateTree.js"
hash_is 8339b3c6b39363a88e2994f6604693890bf210cf7a0ecb3c2c38b53417cd090b "$d/DatesPanel.qml"
hash_is f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0 "$q/notebook-date-index.qmd"
for dir in "$d" "$q" /home/root/.codex-backups; do test "$(readlink -f "$dir")" = "$dir"; done
test -z "$(find "$d" -type l)"; test "$(find "$q" -name '*.qmd' | wc -l)" = 10
extensions=("$x"/extensions.d/*.so); test "${#extensions[@]}" = 4
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
systemctl is-active --quiet xochitl notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
snapshot() {
  sha256sum "$q"/*.qmd | sed '\|/notebook-date-index.qmd$|d'
  sha256sum "$x"/extensions.d/*.so "$d/notebook-date-index"
  sha256sum /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  stat -c '%a %n' /home/root/.config/gestik.json /home/root/.local/share/gestik-beta/gestik.json
  sha256sum /home/root/.local/share/notebook-date-index/{settings.json,token,sync.json}
  sha256sum /home/root/.vellum/lib/apk/db/installed /home/root/.vellum/etc/apk/{world,repositories}
  sha256sum /home/root/.local/lib/rmstream-shortcut/ScreenSharing.qml "$x"/exthome/appload/rmstream/backend/entry "$x"/exthome/appload/rmstream/resources.rcc
  systemctl show notebook-date-index -p MainPID -p NRestarts
}
if [ "$phase" = prepare ]; then
  test ! -e "$rec"; mkdir -m 700 "$rec"
  cp -p "$d/DatesPanel.qml" "$d/DateTree.js" "$q/notebook-date-index.qmd" "$rec/"
  cp -p "$stage/rollback-navigation.sh" "$rec/"
  snapshot > "$rec/before.sha256"
  tar -czf "$rec/safety-backup.tgz" -C /home/root .local/lib/notebook-date-index .local/share/notebook-date-index .config/gestik.json .local/share/gestik-beta/gestik.json xovi/exthome/qt-resource-rebuilder
  chmod 600 "$rec/safety-backup.tgz"; touch "$rec/prepared"; sync
  sha256sum "$rec/safety-backup.tgz"; exit 0
fi
test "$phase" = activate
test -e "$rec/prepared"; test -e "$rec/mac-backup-verified"; test ! -e "$rec/committed"; test ! -e "$rec/rolled-back"
snapshot > "$rec/rechecked.sha256"; cmp "$rec/before.sha256" "$rec/rechecked.sha256"
cmp "$stage/rollback-navigation.sh" "$rec/rollback-navigation.sh"
if systemctl is-active --quiet dates-navigation-rollback.timer; then exit 2; fi
systemd-run --unit=dates-navigation-rollback --on-active=180 --timer-property=AccuracySec=1 bash "$rec/rollback-navigation.sh" "$rec"
systemctl is-active --quiet dates-navigation-rollback.timer
fail() { systemctl start --no-block dates-navigation-rollback.service || true; }
trap fail EXIT HUP INT TERM
for file in DateTree.js DatesPanel.qml notebook-date-index.qmd; do
  dest=$d; if [ "$file" = notebook-date-index.qmd ]; then dest=$q; fi
  cp "$stage/$file" "$dest/$file.navigation-ready"; chmod 600 "$dest/$file.navigation-ready"
  cmp "$stage/$file" "$dest/$file.navigation-ready"; sync; mv "$dest/$file.navigation-ready" "$dest/$file"
done
touch "$rec/activation-attempted"; sync
REMAGIC_SAMPLE_SECONDS=30 "$x/remagic-live-test-safe.sh"
snapshot > "$rec/after.sha256"; cmp "$rec/before.sha256" "$rec/after.sha256"
cmp "$stage/DatesPanel.qml" "$d/DatesPanel.qml"; cmp "$stage/DateTree.js" "$d/DateTree.js"
cmp "$stage/notebook-date-index.qmd" "$q/notebook-date-index.qmd"
if grep -E '(DatesPanel\.qml|DateTree\.js):[0-9]+' /tmp/remagic-live-test.log; then exit 1; fi
if grep -Ei 'ReferenceError|TypeError|is not a type|Cannot assign|failed to load|Non-existent|Unexpected token' /tmp/remagic-live-test.log | grep -E 'Values.qml|Toolbar.qml|SettingsMenu.qml|ndi[A-Z]|ScreenSharing|rmstream'; then exit 1; fi
test "$(systemctl show xochitl -p NRestarts --value)" = 0
systemctl is-active --quiet xochitl notebook-date-index
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
pid=$(systemctl show xochitl -p MainPID --value)
printf 'mode=dates-navigation\npid=%s\n' "$pid" > "$rec/committed.ready"
sync; mv "$rec/committed.ready" "$rec/committed"; sync
trap - EXIT HUP INT TERM
systemctl stop dates-navigation-rollback.timer
cp /tmp/remagic-live-test.log "$rec/xochitl.log"
echo "dates_navigation=passed pid=$pid recovery=$rec"
