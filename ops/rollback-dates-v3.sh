#!/bin/bash
set -eu
rec=${1:?recovery directory}
case "$rec" in /home/root/.codex-backups/dates-v3-*) ;; *) exit 2;; esac
test "$(readlink -f "$rec")" = "$rec"
test -e "$rec/prepared"
test ! -e "$rec/committed" || exit 0
test ! -e "$rec/rolled-back" || exit 0
systemctl kill --kill-whom=all --signal=KILL dates-v3-install.service 2>/dev/null || true
# Never let the old writer parse/rotate schema-2 data. Keep all current data.
if [ "$(systemctl show notebook-date-index -p LoadState --value)" != not-found ]; then
  systemctl stop notebook-date-index
fi
if pidof notebook-date-index >/dev/null; then exit 2; fi
(cd "$rec/old" && sha256sum -c "$rec/old.sha256")
d=/home/root/.local/lib/notebook-date-index
for file in notebook-date-index DatesPanel.qml; do
  cp -p "$rec/old/$file" "$d/$file.rollback-ready"
  cmp "$rec/old/$file" "$d/$file.rollback-ready"
  sync; mv "$d/$file.rollback-ready" "$d/$file"
done
if [ -e "$d/DateTree.js" ]; then mv "$d/DateTree.js" "$rec/failed-DateTree.js"; fi
sync
if [ -e "$rec/activation-attempted" ]; then /home/root/xovi/stock > "$rec/rollback-stock.log" 2>&1; fi
systemctl is-active --quiet xochitl
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
test "$(systemctl show xochitl -p NRestarts --value)" = 0
touch "$rec/rolled-back"
echo 'Rollback complete; Dates intentionally stopped, current history retained. Recover with a schema-2-aware writer.'
