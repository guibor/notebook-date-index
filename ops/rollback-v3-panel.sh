#!/bin/bash
set -eu
rec=${1:?recovery directory}
case "$rec" in /home/root/.codex-backups/dates-v3-panel-*) ;; *) exit 2;; esac
test "$(readlink -f "$rec")" = "$rec"
test -e "$rec/prepared"
test ! -e "$rec/committed" || exit 0
test ! -e "$rec/rolled-back" || exit 0
systemctl kill --kill-whom=all --signal=KILL dates-v3-panel-install.service 2>/dev/null || true
test "$(sha256sum "$rec/old-panel.qml" | cut -d' ' -f1)" = dcbd9a48004e3a302eeb5bf746643e9520c59614807a8ce412184434b678c375
d=/home/root/.local/lib/notebook-date-index
cp -p "$rec/old-panel.qml" "$d/DatesPanel.qml.rollback-ready"
cmp "$rec/old-panel.qml" "$d/DatesPanel.qml.rollback-ready"
sync; mv "$d/DatesPanel.qml.rollback-ready" "$d/DatesPanel.qml"; sync
if [ -e "$rec/activation-attempted" ]; then /home/root/xovi/stock > "$rec/rollback-stock.log" 2>&1; fi
systemctl is-active --quiet xochitl notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
touch "$rec/rolled-back"
