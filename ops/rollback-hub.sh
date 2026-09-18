#!/bin/bash
set -euo pipefail
stage=${1:?stage}
case "$stage" in /home/mdf/.local/share/notebook-date-sync-staging/hub-*) ;; *) exit 2;; esac
test "$(readlink -f "$stage")" = "$stage"
test -f "$stage/prepared"
test ! -f "$stage/committed" || exit 0
systemctl --user kill --kill-whom=all --signal=KILL notebook-date-sync-install.service 2>/dev/null || true
# Restore only our exact patched configuration; don't overwrite concurrent work.
if cmp -s "$stage/nginx.after" /etc/nginx/sites-enabled/anki-mcp; then
  sudo -n install -o root -g root -m 644 "$stage/nginx.before" /etc/nginx/sites-enabled/anki-mcp
  sudo -n nginx -t
  sudo -n systemctl reload nginx
fi
systemctl --user disable --now notebook-date-sync.service 2>/dev/null || true
touch "$stage/rolled-back"
