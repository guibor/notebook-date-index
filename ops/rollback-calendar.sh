#!/bin/bash
set -eu
rec=${1:?recovery directory}
case "$rec" in /home/root/.codex-backups/dates-calendar-*) ;; *) exit 2;; esac
test "$(readlink -f "$rec")" = "$rec"
test -e "$rec/prepared"
test ! -e "$rec/committed" || exit 0
test ! -e "$rec/rolled-back" || exit 0
systemctl kill --kill-whom=all --signal=KILL dates-calendar-install.service 2>/dev/null || true
test "$(sha256sum "$rec/DatesPanel.qml" | cut -d' ' -f1)" = dc1460092f72db8bc3e10295ca0467bce94cbfc18cd66d0746be84290b9e1e00
test "$(sha256sum "$rec/DateTree.js" | cut -d' ' -f1)" = 340239c6fadf7ba761e30a7b77a02de2dd2aa4d21658a57e6575b8a30e93e2d3
d=/home/root/.local/lib/notebook-date-index
for file in DatesPanel.qml DateTree.js; do
  cp -p "$rec/$file" "$d/$file.rollback-ready"
  cmp "$rec/$file" "$d/$file.rollback-ready"
  sync; mv "$d/$file.rollback-ready" "$d/$file"; sync
done
if [ -e "$rec/activation-attempted" ]; then /home/root/xovi/stock > "$rec/rollback-stock.log" 2>&1; fi
systemctl is-active --quiet xochitl notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
touch "$rec/rolled-back"
