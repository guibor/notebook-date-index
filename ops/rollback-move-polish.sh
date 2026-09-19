#!/bin/bash
# Restore only the prior panel/helper; retain the running writer and all history.
set -Eeuo pipefail
rec=${1:?recovery directory}; id=${rec##*/}
[[ "$id" =~ ^dates-move-polish-[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]]
test "$rec" = "/home/root/.codex-backups/$id"
test "$(readlink -f "$rec")" = "$rec"; test -e "$rec/prepared"
test ! -e "$rec/committed" || exit 0
test ! -e "$rec/rolled-back" || exit 0
# Stop only our publication/activation cgroup before allowing any restoration.
# BEGIN installer-quiescence gate (also exercised with mocked systemd/cgroup data).
installer=dates-move-polish-install.service
installer_group="/system.slice/$installer"
installer_quiescent() {
  local load active main control group populated
  load=$(systemctl show "$installer" -p LoadState --value) || return 1
  active=$(systemctl show "$installer" -p ActiveState --value) || return 1
  main=$(systemctl show "$installer" -p MainPID --value) || return 1
  control=$(systemctl show "$installer" -p ControlPID --value) || return 1
  group=$(systemctl show "$installer" -p ControlGroup --value) || return 1
  case "$load" in
    loaded)
      case "$active" in inactive|failed) ;; *) return 1 ;; esac
      test "$main" = 0 && test "$control" = 0 || return 1
      ;;
    not-found)
      # Collected transient units may omit service-only properties.
      case "$active" in ''|inactive) ;; *) return 1 ;; esac
      case "$main:$control" in :|0:|:0|0:0) ;; *) return 1 ;; esac
      test -z "$group" || return 1
      ;;
    *) return 1 ;;
  esac
  case "$group" in ''|"$installer_group") ;; *) return 1 ;; esac
  # Population includes descendants; MainPID alone cannot prove quiescence.
  # Both qualified tablets use this exact cgroup2 mount in a hybrid hierarchy.
  test "$(findmnt -n -o FSTYPE /sys/fs/cgroup/unified)" = cgroup2 || return 1
  test -r /sys/fs/cgroup/unified/cgroup.controllers || return 1
  if test ! -e "/sys/fs/cgroup/unified$installer_group" && test ! -L "/sys/fs/cgroup/unified$installer_group"; then return 0; fi
  test ! -L "/sys/fs/cgroup/unified$installer_group" || return 1
  populated=$(awk '$1 == "populated" { count++; value=$2 } END { if (count != 1) exit 1; print value }' "/sys/fs/cgroup/unified$installer_group/cgroup.events") || return 1
  test "$populated" = 0
}
systemctl kill --kill-whom=all --signal=KILL dates-move-polish-install.service 2>/dev/null || true
quiescent=0
for attempt in $(seq 1 20); do
  if installer_quiescent; then quiescent=1; break; fi
  sleep 1
done
test "$quiescent" = 1
# Commit may win between the first marker check and SIGKILL. Recheck only after
# neither the installer nor any descendant can race with file restoration.
test ! -e "$rec/committed" || exit 0
test ! -e "$rec/rolled-back" || exit 0
# END installer-quiescence gate
test "$(sha256sum "$rec/DatesPanel.qml" | cut -d' ' -f1)" = 6ced2cd45df7513b0572b76a5f955cbdbc9d51ea4810a232511d5c362332944a
test "$(sha256sum "$rec/DateTree.js" | cut -d' ' -f1)" = a91dbdc403f9959490d879a1d52fb5bd2b683d020db2753b55127d678a0b09ce
d=/home/root/.local/lib/notebook-date-index
test "$(readlink -f "$d")" = "$d"
for file in DatesPanel.qml DateTree.js; do
  test ! -L "$d/$file"; cp -p "$rec/$file" "$d/$file.rollback-ready"
  cmp "$rec/$file" "$d/$file.rollback-ready"; sync; mv "$d/$file.rollback-ready" "$d/$file"; sync
done
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
systemctl is-active --quiet notebook-date-index
test "$(systemctl show xochitl -p NRestarts --value)" = 0
if grep -q /home/root/xovi/ "/proc/$pid/maps"; then exit 1; fi
test ! -e /run/systemd/system.control/xochitl.service
test ! -e /run/systemd/system.control/xochitl.service.d/xochitl-service-override.conf
test "$(findmnt -n -o OPTIONS / | cut -d, -f1)" = ro
touch "$rec/rolled-back"; sync
