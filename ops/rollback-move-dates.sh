#!/bin/bash
# Preserve all Dates data; ask the existing watchdog for stock recovery first.
set -euo pipefail
rec=${1:?recovery directory}
test "$rec" = /home/root/.codex-backups/dates-move-20260919-r5
test ! -e "$rec/committed" || exit 0
test ! -e "$rec/rolled-back" || exit 0
runtime=/run/remarkable-beta-os-xovi-session
if systemctl is-active --quiet remarkable-beta-os-xovi-session-watchdog; then
  test "$(sha256sum "$runtime/profile.env" | cut -d' ' -f1)" = 8353dceed76691313bfdda83dc679ca4488af0596daa3ff9dd76683fc84e7dac
  touch "$runtime/deactivate.request"
  recovered=0
  for i in $(seq 1 140); do
    test ! -e "$runtime/recovery.failed" || exit 1
    if [ -e "$runtime/recovery.done" ]; then recovered=1; break; fi
    sleep 2
  done
  test "$recovered" = 1
fi
pid=$(systemctl show xochitl -p MainPID --value)
systemctl is-active --quiet xochitl
if grep -q '/home/root/xovi/' "/proc/$pid/maps"; then exit 1; fi
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
systemctl stop notebook-date-index.service 2>/dev/null || true
test "$(systemctl show notebook-date-index -p MainPID --value)" = 0
q=/home/root/xovi/exthome/qt-resource-rebuilder/notebook-date-index.qmd
if [ -e "$q" ]; then
  test "$(sha256sum "$q" | cut -d' ' -f1)" = f6cba3190f3f690c2729539f0ecc3b629dd0d18366dc22fc5a89174df73731e0
  mv "$q" "$rec/disabled-notebook-date-index.qmd"
fi
touch "$rec/rolled-back"; sync
