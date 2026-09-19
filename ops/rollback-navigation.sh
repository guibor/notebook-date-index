#!/bin/bash
set -eu
rec=${1:?recovery directory}
case "$rec" in /home/root/.codex-backups/dates-navigation-*) ;; *) exit 2;; esac
test "$(readlink -f "$rec")" = "$rec"; test -e "$rec/prepared"
test ! -e "$rec/committed" || exit 0; test ! -e "$rec/rolled-back" || exit 0
systemctl kill --kill-whom=all --signal=KILL dates-navigation-install.service 2>/dev/null || true
hash_is() { test "$(sha256sum "$2" | cut -d' ' -f1)" = "$1"; }
hash_is 8339b3c6b39363a88e2994f6604693890bf210cf7a0ecb3c2c38b53417cd090b "$rec/DatesPanel.qml"
hash_is f37b64247f098c933f3dafe8978f0bc82ca7afda890b8b0f4c7fdcdeedd693e6 "$rec/DateTree.js"
hash_is f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0 "$rec/notebook-date-index.qmd"
for file in DatesPanel.qml DateTree.js notebook-date-index.qmd; do
  dest=/home/root/.local/lib/notebook-date-index
  if [ "$file" = notebook-date-index.qmd ]; then dest=/home/root/xovi/exthome/qt-resource-rebuilder; fi
  cp -p "$rec/$file" "$dest/$file.rollback-ready"; cmp "$rec/$file" "$dest/$file.rollback-ready"
  sync; mv "$dest/$file.rollback-ready" "$dest/$file"; sync
done
if [ -e "$rec/activation-attempted" ]; then /home/root/xovi/stock > "$rec/rollback-stock.log" 2>&1; fi
systemctl is-active --quiet xochitl notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
touch "$rec/rolled-back"
