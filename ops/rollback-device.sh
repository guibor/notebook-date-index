#!/bin/bash
set -eu
rec=${1:?recovery directory}
case "$rec" in /home/root/.codex-backups/ndi-*) ;; *) exit 2;; esac
test "$(readlink -f "$rec")" = "$rec"
test -e "$rec/prepared"
test ! -e "$rec/committed" || exit 0
test ! -e "$rec/rolled-back" || exit 0
systemctl kill --kill-whom=all --signal=KILL notebook-date-index-install.service 2>/dev/null || true
systemctl stop notebook-date-index.service 2>/dev/null || true
q=/home/root/xovi/exthome/qt-resource-rebuilder/notebook-date-index.qmd
if [ -f "$q" ]; then mv "$q" "$rec/failed.qmd"; fi
if [ -f "$rec/prior.qmd" ]; then cp -p "$rec/prior.qmd" "$q"; fi
if [ -f "$rec/prior-panel.qml" ]; then cp -p "$rec/prior-panel.qml" /home/root/.local/lib/notebook-date-index/DatesPanel.qml; fi
sync
if [ -e "$rec/activation-attempted" ]; then
  /home/root/xovi/stock > "$rec/rollback-stock.log" 2>&1
fi
systemctl is-active --quiet xochitl
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
touch "$rec/rolled-back"
