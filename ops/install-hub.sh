#!/bin/bash
set -euo pipefail
stage=${1:?stage}; reviewed=${2:?manifest hash}
endpoint=${3:?explicit HTTPS /dates/v1/exchange URL}; health=${4:?existing service HTTPS health URL}
case "$endpoint" in https://*/dates/v1/exchange) ;; *) exit 2;; esac
case "$health" in https://*) ;; *) exit 2;; esac
case "$stage" in /home/mdf/.local/share/notebook-date-sync-staging/hub-*) ;; *) exit 2;; esac
[[ "$reviewed" =~ ^[a-f0-9]{64}$ ]]
test "$(readlink -f "$stage")" = "$stage"
test "$(hostname)" = md-server
test "$(uname -m)" = x86_64
test "$(id -un)" = mdf
test "$(sha256sum "$stage/SHA256SUMS" | cut -d' ' -f1)" = "$reviewed"
(cd "$stage" && sha256sum -c SHA256SUMS)
test "$(readlink -f /etc/nginx/sites-enabled/anki-mcp)" = /etc/nginx/sites-enabled/anki-mcp
test "$(stat -c '%U %G %a' /etc/nginx/sites-enabled/anki-mcp)" = 'root root 644'
cmp "$stage/nginx.before" /etc/nginx/sites-enabled/anki-mcp
test ! -e /etc/nginx/snippets/dates-sync-location.conf
test ! -e /home/mdf/.config/systemd/user/notebook-date-sync.service
test ! -e /home/mdf/.local/lib/notebook-date-sync
test ! -e /home/mdf/.local/share/notebook-date-sync
test "$(loginctl show-user mdf -p Linger --value)" = yes
if ss -ltn | grep -q ':18743 '; then exit 2; fi
test "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$health")" = 401
systemctl is-active --quiet nginx anki-http anki-mcp-sse
touch "$stage/prepared"
systemd-run --user --unit=notebook-date-sync-rollback --on-active=180 --timer-property=AccuracySec=1 bash "$stage/rollback-hub.sh" "$stage"
systemctl --user is-active --quiet notebook-date-sync-rollback.timer
fail() { systemctl --user start --no-block notebook-date-sync-rollback.service || true; }
trap fail EXIT HUP INT TERM
mkdir -m 700 /home/mdf/.local/lib/notebook-date-sync /home/mdf/.local/share/notebook-date-sync
mkdir -m 700 /home/mdf/.local/share/notebook-date-sync/history
install -m 700 "$stage/notebook-date-index" /home/mdf/.local/lib/notebook-date-sync/notebook-date-index
/home/mdf/.local/lib/notebook-date-sync/notebook-date-index --init-sync-credentials /home/mdf/.local/share/notebook-date-sync/credentials --sync-endpoint "$endpoint"
install -m 600 "$stage/notebook-date-sync.service" /home/mdf/.config/systemd/user/notebook-date-sync.service
systemctl --user daemon-reload
systemctl --user enable --now notebook-date-sync.service
for i in 1 2 3 4 5; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 -X POST http://127.0.0.1:18743/dates/v1/exchange || true)
  if [ "$code" = 401 ]; then break; fi
  sleep 1
done
test "$code" = 401
sudo -n install -m 644 "$stage/dates-sync-location.conf" /etc/nginx/snippets/dates-sync-location.conf
# Recheck shared nginx state immediately before its one-line include addition.
cmp "$stage/nginx.before" /etc/nginx/sites-enabled/anki-mcp
sudo -n install -m 644 "$stage/nginx.after" /etc/nginx/sites-enabled/anki-mcp
sudo -n nginx -t
sudo -n systemctl reload nginx
test "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST "$endpoint")" = 401
test "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$health")" = 401
systemctl is-active --quiet nginx anki-http anki-mcp-sse
systemctl --user is-active --quiet notebook-date-sync.service
test "$(systemctl --user show notebook-date-sync.service -p NRestarts --value)" = 0
touch "$stage/committed"
trap - EXIT HUP INT TERM
systemctl --user stop notebook-date-sync-rollback.timer
echo 'Dates hub installed; HTTPS rejects unauthenticated access; existing health endpoint unchanged'
