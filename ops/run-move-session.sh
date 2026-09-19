#!/bin/bash
# Mac-side upload and fixed-cgroup runner for the Move XOVI session controller.
set -Eeuo pipefail
umask 077

DEVICE=${1:-}
MODE=${2:-status}
ssh_opts=(-o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -i "$HOME/.ssh/id_ed25519_remarkable_new")
case "$DEVICE" in ""|-*|*[!A-Za-z0-9_.@-]*) echo "Pass a safe SSH host" >&2; exit 2 ;; esac
host=${DEVICE#root@}
test "$DEVICE" = "root@$host"
[[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
keys=$(ssh-keyscan -T 3 -t ed25519 "$host" 2>/dev/null)
test "$(printf '%s\n' "$keys" | ssh-keygen -lf - | awk '{print $2}')" = SHA256:osLWO+xA0s/qhzWV2jtGWAF6NlD/KEi/d6CEkt8MZMk
case "$MODE" in activate|deactivate|status) ;; *) echo "Invalid mode" >&2; exit 2 ;; esac
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
profile="$repo/profiles/move-dates-r5.env"
profile_lib="$repo/ops/move-profile-lib.sh"
dropin_lib="$repo/ops/move-runtime/xovi-session-dropins.sh"
watchdog="$repo/ops/move-runtime/xovi-session-watchdog.sh"
controller="$repo/ops/move-runtime/xovi-session-safe.sh"
qmd_manifest="$repo/profiles/move-dates-r5-qmd.sha256"
runtime=/run/remarkable-beta-os-xovi-session
unit=remarkable-beta-os-xovi-session
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
upload="/run/.remarkable-beta-os-xovi-session-upload-$run_id"
upload_started=0
published=0
files=("$profile" "$profile_lib" "$dropin_lib" "$watchdog" "$controller" "$qmd_manifest")
remote_files=(profile.env profile-lib.sh xovi-session-dropins.sh \
    xovi-session-watchdog.sh xovi-session-safe.sh qmd-sha256.txt)

# shellcheck source=profile-lib.sh
source "$profile_lib"
load_exact_move_profile "$profile"
for file in "${files[@]}"; do
    test -f "$file"
    test ! -L "$file"
done
for syntax_input in "$profile_lib" "$dropin_lib" "$watchdog" "$controller"; do
    bash -n "$syntax_input"
done

cleanup_upload() {
    rc=$?
    trap - EXIT HUP INT TERM
    if test "$MODE" = activate && test "$upload_started" -eq 1 &&
       test "$published" -ne 1; then
        ssh "${ssh_opts[@]}" "$DEVICE" "rm -rf '$upload'" \
            >/dev/null 2>&1 || true
    fi
    exit "$rc"
}
trap cleanup_upload EXIT HUP INT TERM

if test "$MODE" = activate; then
    ssh "${ssh_opts[@]}" "$DEVICE" "set -eu
test ! -e '$runtime'; test ! -L '$runtime'
test ! -e '$upload'; test ! -L '$upload'
mkdir -m 0700 '$upload'"
    upload_started=1
    for index in 0 1 2 3 4 5; do
        scp -O -q "${ssh_opts[@]}" "${files[$index]}" \
            "$DEVICE:$upload/${remote_files[$index]}"
    done
    for index in 0 1 2 3 4 5; do
        local_sha=$(shasum -a 256 "${files[$index]}" | awk '{print $1}')
        ssh "${ssh_opts[@]}" "$DEVICE" "set -eu
test ! -L '$upload/${remote_files[$index]}'
test \"\$(sha256sum '$upload/${remote_files[$index]}' | cut -d' ' -f1)\" = '$local_sha'
chown root:root '$upload/${remote_files[$index]}'
chmod 0600 '$upload/${remote_files[$index]}'"
    done
    ssh "${ssh_opts[@]}" "$DEVICE" \
        "set -eu
chmod 0700 '$upload/xovi-session-watchdog.sh' '$upload/xovi-session-safe.sh'
test ! -e '$runtime'; test ! -L '$runtime'
mv '$upload' '$runtime'
sync"
    published=1
else
    for index in 0 1 2 3 4 5; do
        local_sha=$(shasum -a 256 "${files[$index]}" | awk '{print $1}')
        ssh "${ssh_opts[@]}" "$DEVICE" "set -eu
test -f '$runtime/${remote_files[$index]}'
test ! -L '$runtime/${remote_files[$index]}'
test \"\$(sha256sum '$runtime/${remote_files[$index]}' | cut -d' ' -f1)\" = '$local_sha'"
    done
fi

trap - EXIT HUP INT TERM

remote_env="PROFILE=$runtime/profile.env PROFILE_LIB=$runtime/profile-lib.sh DROPIN_LIB=$runtime/xovi-session-dropins.sh WATCHDOG_SCRIPT=$runtime/xovi-session-watchdog.sh QMD_MANIFEST=$runtime/qmd-sha256.txt"
if test "$MODE" = status; then
    ssh "${ssh_opts[@]}" "$DEVICE" \
        "/usr/bin/env $remote_env /bin/bash '$runtime/xovi-session-safe.sh' status"
else
    ssh "${ssh_opts[@]}" "$DEVICE" "set -eu
systemctl reset-failed '$unit.service' 2>/dev/null || true
systemd-run --collect --wait --pipe --unit='$unit' \
  --property=Type=exec --property=KillMode=control-group \
  /usr/bin/env $remote_env \
  /bin/bash '$runtime/xovi-session-safe.sh' '$MODE'"
fi
